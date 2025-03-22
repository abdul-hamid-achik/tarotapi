require "rainbow"
require "json"
require "fileutils"
require_relative '../divination_logger'
require_relative '../github_actions_runner'

namespace :ci do
  # Event files directory
  EVENT_FILES_DIR = ".github/workflow-events"

  # Create event files directory if it doesn't exist
  FileUtils.mkdir_p(EVENT_FILES_DIR)

  desc "Ensure Docker CLI is available for act"
  task :ensure_docker_cli do
    DivinationLogger.divine_ritual("Ensuring Docker CLI is available") do
      # Check if Docker CLI is installed
      if system("which docker > /dev/null 2>&1")
        DivinationLogger.divine("Docker CLI is already installed.")
      else
        DivinationLogger.prophecy("Docker CLI is not installed. Installing now...")
        
        # Create a Dockerfile specifically for act to ensure Docker CLI is available
        dockerfile_content = <<~DOCKERFILE
          FROM catthehacker/ubuntu:act-latest
          RUN apt-get update && apt-get install -y docker.io
        DOCKERFILE
        
        File.write(".act_dockerfile", dockerfile_content)
        
        # Build the Docker image for act
        system("docker build -t act-with-docker -f .act_dockerfile .")
        
        # Update .actrc to use this image
        current_actrc = File.read(".actrc").strip
        new_actrc = current_actrc.gsub(/^-P ubuntu-latest=.*/, "-P ubuntu-latest=act-with-docker")
        File.write(".actrc", new_actrc)
        
        DivinationLogger.divine("Docker CLI installation complete for act.")
      end
    end
  end

  desc "Build the CI Docker image using development stage from main Dockerfile (ARM-optimized)"
  task :build_image do
    DivinationLogger.divine_ritual("Building CI Docker image") do
      arch = `uname -m`.strip
      DivinationLogger.reveal("Detected architecture: #{arch}")
      sh "docker build -t tarot-api-ci:latest --target development --build-arg BUILDKIT_INLINE_CACHE=1 ."
    end
  end

  desc "Run all CI checks locally"
  task :all do
    DivinationLogger.divine_ritual("Running all CI checks") do
      runner = GitHubActionsRunner.new
      success = runner.run_workflow("push", filter_output: true)
      raise "CI checks failed" unless success
    end
  end
  
  desc "Run all CI checks with verbose output (noisy)"
  task :all_verbose do
    DivinationLogger.divine_ritual("Running all CI checks with verbose output") do
      runner = GitHubActionsRunner.new
      success = runner.run_workflow("push", filter_output: false, verbose: true)
      raise "CI checks failed" unless success
    end
  end
  
  desc "Run all CI checks silently"
  task :all_silent do
    DivinationLogger.divine_ritual("Running all CI checks silently") do
      runner = GitHubActionsRunner.new
      success = runner.run_workflow("push", silence_output: true)
      if success
        DivinationLogger.divine("All CI checks passed successfully")
      else
        DivinationLogger.prophecy("CI checks failed")
        raise "CI checks failed"
      end
    end
  end

  desc "Run linting checks"
  task :lint do
    DivinationLogger.divine_ritual("Running linting checks") do
      runner = GitHubActionsRunner.new
      success = runner.run_workflow(nil, job: "lint", filter_output: true)
      raise "Linting failed" unless success
    end
  end

  desc "Run tests with ARM optimizations"
  task test: :ensure_image do
    DivinationLogger.divine_ritual("Running tests") do
      sh "docker run --rm -e RAILS_ENV=test tarot-api-ci:latest bundle exec rake test"
    end
  end

  task :ensure_image do
    unless ENV["CI"]
      unless system("docker image inspect tarot-api-ci:latest > /dev/null 2>&1")
        DivinationLogger.obscure("CI image not found, building now...")
        Rake::Task["ci:build_image"].invoke
      end
    end
  end

  desc "Generate API docs locally"
  task :docs do
    DivinationLogger.divine_ritual("Generating API docs") do
      runner = GitHubActionsRunner.new
      success = runner.run_workflow(nil, job: "docs", filter_output: true)
      raise "API docs generation failed" unless success
    end
  end

  desc "Run security scan locally"
  task :security do
    DivinationLogger.divine_ritual("Running security scan") do
      runner = GitHubActionsRunner.new
      success = runner.run_workflow(nil, job: "security", filter_output: true)
      raise "Security scan failed" unless success
    end
  end

  # Workflow visualization tasks
  namespace :visualize do
    desc "Visualize all workflow dependencies"
    task :all do
      DivinationLogger.divine_ritual("Visualizing all workflows") do
        runner = GitHubActionsRunner.new
        runner.visualize_workflows
      end
    end

    desc "Visualize a specific workflow by name (e.g., ci.yml)"
    task :workflow, [:name] do |_, args|
      workflow_name = args[:name] || ENV['WORKFLOW']
      if workflow_name.nil? || workflow_name.empty?
        DivinationLogger.prophecy("Please specify a workflow name: rake ci:visualize:workflow[ci.yml]")
      else
        DivinationLogger.divine_ritual("Visualizing workflow: #{workflow_name}") do
          runner = GitHubActionsRunner.new
          runner.visualize_workflows(workflow_name)
        end
      end
    end
    
    desc "Generate a graph of workflow dependencies using act"
    task :graph, [:name] do |_, args|
      workflow_name = args[:name] || ENV['WORKFLOW']
      DivinationLogger.divine_ritual("Generating workflow graph#{workflow_name ? " for #{workflow_name}" : ''}") do
        cmd = ["act -g"]
        cmd << "-W .github/workflows/#{workflow_name}" if workflow_name
        DivinationLogger.reveal("Running: #{cmd.join(' ')}")
        system(cmd.join(' '))
      end
    end
  end

  # Workflow simulation tasks
  namespace :simulate do
    desc "Simulate pull request event"
    task :pr do
      DivinationLogger.divine_ritual("Simulating pull request") do
        runner = GitHubActionsRunner.new
        event_data = {
          action: "opened",
          pull_request: {
            number: 123,
            head: { ref: "feature/test", sha: "abc123" },
            base: { ref: "main", sha: "def456" }
          },
          repository: {
            name: "tarot-api",
            full_name: "Abdul Hamid Achik",
            owner: {
              login: "abdul-hamid-achik"
            }
          }
        }
        # Run only the build_and_push_image job and consider it a success if that job completes
        success = runner.run_workflow("pull_request", job: "build_and_push_image", event_data: event_data, filter_output: true)
        raise "Pull request simulation failed" unless success
      end
    end

    desc "Simulate push to main"
    task :push_main do
      DivinationLogger.divine_ritual("Simulating push to main") do
        runner = GitHubActionsRunner.new
        event_data = {
          ref: "refs/heads/main",
          head_commit: { id: "abc123" }
        }
        success = runner.run_workflow("push", event_data: event_data, filter_output: true)
        raise "Push simulation failed" unless success
      end
    end

    desc "Simulate workflow dispatch"
    task :workflow_dispatch do
      DivinationLogger.divine_ritual("Simulating workflow dispatch") do
        runner = GitHubActionsRunner.new
        event_data = {
          inputs: { environment: "production" }
        }
        success = runner.run_workflow("workflow_dispatch", event_data: event_data, filter_output: true)
        raise "Workflow dispatch simulation failed" unless success
      end
    end

    desc "Run all simulations"
    task :all do
      DivinationLogger.divine_ritual("Running all simulations") do
        %w[pr push_main workflow_dispatch].each do |task|
          DivinationLogger.reveal("Running #{task} simulation")
          Rake::Task["ci:simulate:#{task}"].invoke
        end
      end
    end
    
    desc "Run all simulations silently"
    task :all_silent do
      DivinationLogger.divine_ritual("Running all simulations silently") do
        runner = GitHubActionsRunner.new
        
        DivinationLogger.reveal("Simulating pull request...")
        pr_data = {
          action: "opened",
          pull_request: {
            number: 123,
            head: { ref: "feature/test", sha: "abc123" },
            base: { ref: "main", sha: "def456" }
          }
        }
        pr_success = runner.run_workflow("pull_request", event_data: pr_data, silence_output: true)
        
        DivinationLogger.reveal("Simulating push to main...")
        push_data = {
          ref: "refs/heads/main",
          head_commit: { id: "abc123" }
        }
        push_success = runner.run_workflow("push", event_data: push_data, silence_output: true)
        
        DivinationLogger.reveal("Simulating workflow dispatch...")
        dispatch_data = {
          inputs: { environment: "production" }
        }
        dispatch_success = runner.run_workflow("workflow_dispatch", event_data: dispatch_data, silence_output: true)
        
        if pr_success && push_success && dispatch_success
          DivinationLogger.divine("All simulations completed successfully")
        else
          failures = []
          failures << "Pull request" unless pr_success
          failures << "Push to main" unless push_success
          failures << "Workflow dispatch" unless dispatch_success
          DivinationLogger.prophecy("Some simulations failed: #{failures.join(', ')}")
          raise "Simulation failures: #{failures.join(', ')}"
        end
      end
    end
  end

  desc "Test act command integration"
  task :test_act do
    DivinationLogger.divine_ritual("Testing act command integration") do
      runner = GitHubActionsRunner.new
      
      # Test with specific event type
      DivinationLogger.reveal("Testing with push event...")
      cmd_push = runner.send(:build_command, "push", nil, nil, false)
      DivinationLogger.reveal("Command: #{cmd_push}")
      
      # Test with job specified
      DivinationLogger.reveal("Testing with specific job...")
      cmd_job = runner.send(:build_command, nil, "lint", nil, false)
      DivinationLogger.reveal("Command: #{cmd_job}")
      
      # Test with event file
      DivinationLogger.reveal("Testing with event file...")
      event_file = "/tmp/test_event.json"
      cmd_event = runner.send(:build_command, "push", nil, event_file, false)
      DivinationLogger.reveal("Command: #{cmd_event}")
      
      # Test with all options
      DivinationLogger.reveal("Testing with all options...")
      cmd_all = runner.send(:build_command, "push", "lint", event_file, true)
      DivinationLogger.reveal("Command: #{cmd_all}")
    end
  end
end

task ci: "ci:all"
