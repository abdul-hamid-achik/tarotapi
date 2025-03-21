require "rainbow"

namespace :ci do
  desc "Build the CI Docker image"
  task :build_image do
    sh "docker build -t tarot-api-ci:latest -f Dockerfile.ci --target ci ."
  end

  desc "Run all CI checks locally using act"
  task :all do
    puts Rainbow("Running all CI checks locally").bright.green
    sh "act -P ubuntu-latest=ghcr.io/catthehacker/ubuntu:act-latest -b"
  end

  desc "Run linting checks only"
  task :lint do
    puts Rainbow("Running linting checks").yellow
    sh "act -j lint -P ubuntu-latest=ghcr.io/catthehacker/ubuntu:act-latest -b"
  end

  desc "Run tests only"
  task :test do
    puts Rainbow("Running tests").yellow
    sh "act -j test -P ubuntu-latest=ghcr.io/catthehacker/ubuntu:act-latest -b"
  end

  desc "Generate API docs locally"
  task :docs do
    puts Rainbow("Generating API docs").yellow
    sh "act -j docs -P ubuntu-latest=ghcr.io/catthehacker/ubuntu:act-latest -b"
  end
  
  desc "Run security scan locally"
  task :security do
    puts Rainbow("Running security scan").yellow
    sh "act -j security -P ubuntu-latest=ghcr.io/catthehacker/ubuntu:act-latest -b"
  end
  
  desc "Simulate a full deployment workflow locally"
  task :deploy do
    puts Rainbow("Simulating deployment workflow").yellow
    sh "act workflow_dispatch -P ubuntu-latest=ghcr.io/catthehacker/ubuntu:act-latest -b -e .github/workflows/act-deployment-event.json"
  end
  
  desc "Create or update the act deployment event JSON file"
  task :setup_deploy_event do
    event_file = ".github/workflows/act-deployment-event.json"
    
    content = {
      "inputs" => {
        "environment" => "staging",
        "version" => "local-test"
      }
    }
    
    File.write(event_file, JSON.pretty_generate(content))
    puts Rainbow("Created #{event_file} for local deployment testing").green
  end
  
  desc "Generate a workflow documentation markdown file"
  task :docs_workflows do
    output_file = "docs/ci_cd_workflows.md"
    FileUtils.mkdir_p(File.dirname(output_file))
    
    workflows = Dir.glob(".github/workflows/*.yml").sort
    
    content = "# CI/CD Workflows Documentation\n\n"
    content += "This document provides an overview of our GitHub Actions workflows.\n\n"
    
    workflows.each do |workflow_file|
      filename = File.basename(workflow_file)
      content += "## #{filename}\n\n"
      
      yaml_content = YAML.load_file(workflow_file)
      
      # Add description if available
      if yaml_content['name']
        content += "**#{yaml_content['name']}**\n\n"
      end
      
      # Add purpose
      content += "### Purpose\n\n"
      case filename
      when "ci.yml"
        content += "Runs tests, linting, and other checks on pull requests and pushes to main.\n\n"
      when "build-image.yml"
        content += "Builds and pushes Docker images to our container registry.\n\n"
      when "security-scan.yml"
        content += "Runs security scans to identify vulnerabilities in the codebase.\n\n"
      when "preview-environments.yml"
        content += "Creates temporary preview environments for feature branches.\n\n"
      when "cleanup-previews.yml"
        content += "Cleans up inactive preview environments to save resources.\n\n"
      when "infra-deploy.yml"
        content += "Deploys infrastructure changes using Pulumi.\n\n"
      when "dependabot-auto-merge.yml"
        content += "Automatically merges safe dependency updates from Dependabot.\n\n"
      when "subscriptions.yml"
        content += "Manages user subscription-related tasks.\n\n"
      else
        content += "Provides automation for the application.\n\n"
      end
      
      # Add trigger information
      content += "### Triggers\n\n"
      if yaml_content['on']
        triggers = yaml_content['on']
        if triggers.is_a?(Hash)
          triggers.each do |trigger, config|
            content += "- **#{trigger}**"
            if config.is_a?(Hash) && !config.empty?
              content += ": "
              if config['branches']
                content += "branches [#{Array(config['branches']).join(', ')}]"
              end
              if config['paths']
                content += ", paths [#{Array(config['paths']).join(', ')}]"
              end
            end
            content += "\n"
          end
        else
          content += "- **#{triggers}**\n"
        end
      end
      content += "\n"
      
      # Add jobs summary
      content += "### Jobs\n\n"
      if yaml_content['jobs']
        yaml_content['jobs'].each do |job_id, job_config|
          job_name = job_config['name'] || job_id
          content += "- **#{job_name}**"
          if job_config['needs']
            content += " (depends on: #{Array(job_config['needs']).join(', ')})"
          end
          content += "\n"
        end
      end
      
      content += "\n---\n\n"
    end
    
    File.write(output_file, content)
    puts Rainbow("Generated workflow documentation at #{output_file}").green
  end
end

# Set default task
task :ci => "ci:all" 