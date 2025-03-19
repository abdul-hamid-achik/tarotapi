namespace :ci do
  desc "run github actions locally using act"
  task :local do
    puts "running github actions locally using act..."

    # check if act is installed
    unless system("which act > /dev/null 2>&1")
      puts "error: 'act' is not installed. please install it first:"
      puts "  brew install act     # macos with homebrew"
      puts "  or visit https://github.com/nektos/act for other installation methods"
      exit 1
    end

    # run act with default job or specified job
    job = ENV["JOB"]
    cmd = job.nil? ? "act" : "act -j #{job}"

    if system(cmd)
      puts "github actions ran successfully locally"
    else
      puts "github actions failed locally"
      exit 1
    end
  end

  desc "run github actions api documentation job locally"
  task :local_docs do
    puts "running api documentation generation locally..."
    ENV["JOB"] = "docs"
    Rake::Task["ci:local"].invoke
  end

  desc "list all available jobs in github workflows"
  task :list_jobs do
    puts "listing available jobs in github workflows..."

    # check if act is installed
    unless system("which act > /dev/null 2>&1")
      puts "error: 'act' is not installed. please install it first:"
      puts "  brew install act     # macos with homebrew"
      puts "  or visit https://github.com/nektos/act for other installation methods"
      exit 1
    end

    # list jobs with act
    system("act -l")
  end

  desc "generate and test api documentation"
  task docs: :environment do
    puts "generating and testing api documentation..."

    if system("RAILS_ENV=test bundle exec rake api:docs")
      puts "api documentation generated successfully"

      if system("RAILS_ENV=test bundle exec rake api:validate")
        puts "api validation successful"
      else
        puts "api validation failed"
        exit 1
      end
    else
      puts "failed to generate api documentation"
      exit 1
    end
  end
end
