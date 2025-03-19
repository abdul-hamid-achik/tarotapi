namespace :docker do
  desc "ensure docker is installed"
  task :check_installed do
    unless system("which docker > /dev/null 2>&1")
      abort "error: docker is not installed. please install docker following the instructions at https://docs.docker.com/get-docker/"
    end

    unless system("which docker-compose > /dev/null 2>&1") && system("which docker compose > /dev/null 2>&1")
      abort "error: docker compose is not installed or not in path. please install docker compose."
    end

    puts "docker is installed"
  end

  desc "start all containers"
  task start: :check_installed do
    if system("docker compose ps api | grep -q 'Up'")
      puts "containers already running"
    else
      system("docker compose up -d") || abort("failed to start containers")

      puts "waiting for containers to be ready..."
      30.times do
        break if system("docker compose ps api | grep -q 'Up'")
        print "."
        sleep 1
      end
      puts ""

      if system("docker compose ps api | grep -q 'Up'")
        puts "containers started successfully"
      else
        abort "containers failed to start"
      end
    end
  end

  desc "stop all containers"
  task stop: :check_installed do
    system("docker compose stop") || abort("failed to stop containers")
    puts "containers stopped"
  end

  desc "restart all containers"
  task restart: [ :stop, :start ] do
    puts "containers restarted"
  end

  desc "rebuild all containers"
  task rebuild: :check_installed do
    system("docker compose down -v") || abort("failed to remove containers")
    system("docker compose build --no-cache") || abort("failed to rebuild containers")
    Rake::Task["docker:start"].invoke
    puts "containers rebuilt and started"
  end

  desc "view container logs"
  task logs: :check_installed do
    exec("docker compose logs -f")
  end

  desc "setup minio for local development"
  task setup_minio: :start do
    # wait for minio to be ready
    30.times do
      break if system("docker compose ps minio | grep -q 'healthy'")
      print "."
      sleep 1
    end
    puts ""

    # setup minio client and create bucket
    system("docker compose exec minio mc alias set local http://localhost:9000 minioadmin minioadmin")
    system("docker compose exec minio mc mb tarot-api --ignore-existing")
    system("docker compose exec minio mc anonymous set download tarot-api")

    puts "minio setup complete"
  end

  desc "run a command in the api container"
  task :exec, [ :cmd ] => :start do |_, args|
    cmd = args[:cmd] || "bash"
    uid = "#{Process.uid}:#{Process.gid}"
    env = "CURRENT_UID=#{uid}"

    exec("#{env} docker compose exec api #{cmd}")
  end

  desc "run the rails console in the api container"
  task console: :start do
    Rake::Task["docker:exec"].invoke("bundle exec rails console")
  end

  desc "run the database console in the api container"
  task dbconsole: :start do
    Rake::Task["docker:exec"].invoke("bundle exec rails dbconsole")
  end
end
