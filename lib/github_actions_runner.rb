require 'json'
require 'fileutils'
require 'yaml'
require 'open3'
require_relative 'divination_logger'

class GitHubActionsRunner
  EVENT_FILES_DIR = ".github/workflow-events"
  WORKFLOWS_DIR = ".github/workflows"

  def initialize
    FileUtils.mkdir_p(EVENT_FILES_DIR)
  end

  # Run a GitHub Actions workflow locally
  # @param event_type [String] The event type (e.g., "push", "pull_request")
  # @param job [String] Specific job to run
  # @param event_data [Hash] Event payload data
  # @param silence_output [Boolean] Whether to silence act output
  # @param filter_output [Boolean] Whether to filter and format act output
  # @param verbose [Boolean] Show verbose output
  # @return [Boolean] Success or failure
  def run_workflow(event_type, job: nil, event_data: {}, silence_output: false, filter_output: true, verbose: false)
    event_file = create_event_file(event_type, event_data)
    cmd = build_command(event_type, job, event_file, verbose)
    
    if silence_output
      # Run completely silently
      _, status = Open3.capture2e(cmd)
      return status.success?
    elsif filter_output
      # Filter and format output
      run_with_filtered_output(cmd)
    else
      # Run with full output
      system(cmd)
    end
  end

  # Visualize workflow job dependencies 
  def visualize_workflows(workflow_name = nil)
    DivinationLogger.divine("✨ Visualizing GitHub Actions Workflows ✨")
    
    workflow_files = workflow_name ? ["#{WORKFLOWS_DIR}/#{workflow_name}"] : Dir.glob("#{WORKFLOWS_DIR}/*.yml")
    
    if workflow_files.empty?
      DivinationLogger.prophecy("No workflow files found in #{WORKFLOWS_DIR}")
      return
    end
    
    workflow_files.each do |workflow_file|
      visualize_workflow(workflow_file)
      DivinationLogger.reveal("\n")
    end
  end
  
  private

  def create_event_file(event_type, data)
    file_path = "#{EVENT_FILES_DIR}/#{event_type}_#{Time.now.to_i}.json"
    File.write(file_path, JSON.pretty_generate(data))
    file_path
  end

  def build_command(event_type, job, event_file, verbose)
    # Important: In act v0.2.75+, the command structure is:
    # act [flags] [event name]
    # The event name (if provided) must be the last argument
    cmd = ["act"]
    
    # Don't add platform or bind options here - they're already in .actrc
    
    cmd << "-j #{job}" if job
    cmd << "-e #{event_file}" if event_file
    cmd << "-v" if verbose
    # The event type must be the last argument
    cmd << event_type if event_type
    cmd.join(" ")
  end

  def run_with_filtered_output(cmd)
    success = false
    started = false
    
    DivinationLogger.reveal("🔄 Running act command: #{cmd}")
    
    Open3.popen2e(cmd) do |stdin, stdout_err, wait_thr|
      stdout_err.each_line do |line|
        # Filter and transform output
        if line.match?(/^\[.*\]\s.*$/) # GitHub Actions step output
          DivinationLogger.reveal("  #{line.strip}")
          started = true
        elsif line.match?(/Error:|Failed:|fatal:/i) # Error messages
          DivinationLogger.prophecy(line.strip)
        elsif started && !line.strip.empty? && !line.match?(/Step \d+\/\d+/)
          # Only show useful output after the workflow starts
          DivinationLogger.obscure("  #{line.strip}") 
        end
      end
      
      success = wait_thr.value.success?
    end
    
    if success
      DivinationLogger.divine("✅ Workflow completed successfully")
    else
      DivinationLogger.prophecy("❌ Workflow failed")
    end
    
    success
  end
  
  def visualize_workflow(workflow_file)
    return unless File.exist?(workflow_file)
    
    begin
      workflow = YAML.load_file(workflow_file)
      filename = File.basename(workflow_file)
      name = workflow["name"] || filename
      
      DivinationLogger.divine("🔮 #{name} (#{filename})")
      DivinationLogger.reveal("  Triggers: #{format_triggers(workflow['on'])}")
      
      if workflow["jobs"].nil? || workflow["jobs"].empty?
        DivinationLogger.obscure("  No jobs defined in this workflow")
        return
      end
      
      # Build dependency graph
      jobs = workflow["jobs"]
      dependencies = build_dependency_graph(jobs)
      
      # Find root jobs (jobs with no dependencies)
      root_jobs = jobs.keys.select { |job_id| jobs[job_id]["needs"].nil? || jobs[job_id]["needs"].empty? }
      
      # Visualize the graph
      DivinationLogger.reveal("  Jobs and Dependencies:")
      root_jobs.each do |job_id|
        render_job_tree(job_id, jobs, dependencies, "  ├── ", "  │   ")
      end
    rescue => e
      DivinationLogger.prophecy("Error visualizing workflow #{workflow_file}: #{e.message}")
    end
  end
  
  def render_job_tree(job_id, jobs, dependencies, prefix, indent)
    job = jobs[job_id]
    job_name = job["name"] || job_id
    
    # Display the current job
    if dependencies[job_id] && !dependencies[job_id].empty?
      DivinationLogger.reveal("#{prefix}🔷 #{job_name} (#{job_id})")
    else
      DivinationLogger.reveal("#{prefix}🔶 #{job_name} (#{job_id}) - Terminal Job")
    end
    
    # Render children
    child_jobs = dependencies[job_id] || []
    last_index = child_jobs.size - 1
    
    child_jobs.each_with_index do |child_id, index|
      is_last = index == last_index
      new_prefix = indent + (is_last ? "└── " : "├── ")
      new_indent = indent + (is_last ? "    " : "│   ")
      render_job_tree(child_id, jobs, dependencies, new_prefix, new_indent)
    end
  end
  
  def build_dependency_graph(jobs)
    # Create a reverse dependency map: job_id => [jobs that depend on it]
    dependencies = {}
    
    jobs.each do |job_id, job|
      dependencies[job_id] ||= []
      
      # Process jobs that this job depends on
      if job["needs"]
        needs = job["needs"].is_a?(Array) ? job["needs"] : [job["needs"]]
        needs.each do |need|
          dependencies[need] ||= []
          dependencies[need] << job_id
        end
      end
    end
    
    dependencies
  end
  
  def format_triggers(triggers)
    return "manual" unless triggers

    if triggers.is_a?(Hash)
      triggers.keys.join(", ")
    else
      triggers.to_s
    end
  end
end 