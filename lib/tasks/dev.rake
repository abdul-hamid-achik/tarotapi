module DockerHelper
  def self.ensure_containers_running
    return if system('docker compose ps api | grep -q "Up"')
    system('docker compose up -d')
    
    30.times do
      break if system('docker compose ps api | grep -q "Up"')
      sleep 1
    end
    
    unless system('docker compose ps api | grep -q "Up"')
      puts 'containers failed to start'
      exit 1
    end
  end

  def self.ensure_bundle_installed
    unless system('docker compose exec api bundle check > /dev/null 2>&1')
      system('docker compose exec api bundle install') || exit(1)
    end
  end

  def self.setup_minio
    # wait for minio to be ready
    30.times do
      break if system('docker compose ps minio | grep -q "healthy"')
      sleep 1
    end

    # setup minio client and create bucket
    system('docker compose exec minio mc alias set local http://localhost:9000 minioadmin minioadmin')
    system('docker compose exec minio mc mb local/tarot-api --ignore-existing')
    system('docker compose exec minio mc anonymous set download local/tarot-api')
  end

  def self.run_in_docker(cmd, interactive: false)
    ensure_containers_running
    ensure_bundle_installed
    
    uid = "#{Process.uid}:#{Process.gid}"
    env = "CURRENT_UID=#{uid}"
    
    docker_cmd = "#{env} docker compose exec"
    docker_cmd += ' -it' if interactive
    docker_cmd += ' api'
    
    full_cmd = "#{docker_cmd} #{cmd}"
    
    if interactive
      exec(full_cmd)
    else
      system(full_cmd) || exit(1)
    end
  end
end

desc 'start development environment with file watching'
task :start do
  Rake::Task['docker:watch'].invoke
end

desc 'setup development environment'
task :setup do
  Rake::Task['dev:setup'].invoke
end

namespace :dev do
  desc 'build containers without affecting running ones'
  task :build do
    system('docker compose build') || exit(1)
  end

  desc 'rebuild containers (stops, removes and rebuilds everything)'
  task :rebuild do
    system('docker compose down && docker compose up --build -d') || exit(1)
    
    puts 'waiting for containers to be healthy...'
    containers = ['api', 'postgres', 'redis', 'minio']
    max_attempts = 30
    success = false
    
    max_attempts.times do |i|
      healthy_count = 0
      containers.each do |container|
        if system("docker compose ps #{container} | grep -q 'healthy'")
          healthy_count += 1
        end
      end
      
      if healthy_count == containers.length
        puts "\nall containers are healthy!"
        success = true
        break
      end
      
      print '.' if (i + 1) % 5 == 0
      sleep 1
    end
    
    unless success
      puts "\ncontainers failed to start. current status:"
      system('docker compose ps')
      exit 1
    end
  end

  desc 'setup development environment'
  task setup: :environment do
    Rake::Task['dev:rebuild'].invoke
    DockerHelper.ensure_bundle_installed
    DockerHelper.setup_minio
    
    # create database using psql
    system('docker compose exec postgres psql -U tarot_api -c "create database tarot_api_development;"')
    DockerHelper.run_in_docker('bundle exec rails db:migrate')
    DockerHelper.run_in_docker('bundle exec rails db:seed')
    Rake::Task['docs:generate'].invoke
    
    puts 'development environment setup complete'
    puts "to start development: rake start"
  end

  desc 'reset development environment'
  task reset: :environment do
    DockerHelper.ensure_containers_running
    DockerHelper.run_in_docker('bundle exec rails db:drop db:create db:migrate db:seed')
  end

  desc 'run rspec tests'
  task :test, [:file] => :environment do |_t, args|
    cmd = 'bundle exec rspec'
    cmd += " #{args[:file]}" if args[:file]
    
    DockerHelper.ensure_containers_running
    DockerHelper.run_in_docker(cmd)
  end

  desc 'run cucumber features'
  task :cucumber, [:feature] => :environment do |_t, args|
    cmd = 'bundle exec cucumber'
    cmd += " #{args[:feature]}" if args[:feature]
    
    DockerHelper.ensure_containers_running
    DockerHelper.run_in_docker(cmd)
  end

  desc 'run all tests (both rspec and cucumber)'
  task :test_all => :environment do
    DockerHelper.ensure_containers_running
    DockerHelper.run_in_docker('bundle exec rspec && bundle exec cucumber')
  end

  # alias for test_all
  desc 'alias for test_all'
  task :full_test => :test_all

  desc 'run tests in parallel'
  task parallel_test: :environment do
    DockerHelper.ensure_containers_running
    DockerHelper.run_in_docker('PARALLEL_WORKERS=4 bundle exec parallel_rspec spec/')
  end

  desc 'run linter'
  task lint: :environment do
    DockerHelper.ensure_containers_running
    DockerHelper.run_in_docker('bundle exec rubocop -a')
  end

  desc 'run console'
  task console: :environment do
    DockerHelper.ensure_containers_running
    DockerHelper.run_in_docker('bundle exec rails console', interactive: true)
  end

  desc 'run bash shell'
  task shell: :environment do
    DockerHelper.ensure_containers_running
    DockerHelper.run_in_docker('/bin/bash', interactive: true)
  end
end

namespace :docs do
  desc 'generate api documentation'
  task generate: :environment do
    DockerHelper.ensure_containers_running
    DockerHelper.run_in_docker('bundle exec rails db:test:prepare')
    DockerHelper.run_in_docker('bundle exec rails rswag:specs:swaggerize')
  end
end

namespace :docker do
  desc 'start development environment with file watching'
  task :watch do
    exec('docker compose watch')
  end

  desc 'view container logs'
  task :logs do
    exec('docker compose logs -f')
  end

  desc 'ssh into api container'
  task :ssh do
    DockerHelper.run_in_docker('/bin/bash', interactive: true)
  end

  desc 'clean docker environment'
  task :clean do
    system('docker compose down -v')
    system('docker compose rm -f')
  end
end 