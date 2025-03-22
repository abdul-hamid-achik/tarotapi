namespace :ollama do
  desc "Pull an Ollama model"
  task :pull, [:model] do |_, args|
    require 'rainbow/refinement'
    using Rainbow
    
    model = args[:model] || ENV.fetch('OLLAMA_MODEL', 'llama3:8b')
    
    puts "Pulling model #{model} in Ollama...".bright.green
    
    # Check if Ollama service is running
    if OllamaService.check_status
      puts "✅ Ollama service running"
    else
      puts "⚠️ Ollama service not running. Starting container...".yellow
      system("docker compose up -d ollama")
      
      # Wait for service to start
      puts "Waiting for Ollama service to start..."
      30.times do
        break if OllamaService.check_status
        print "."
        sleep 1
      end
      puts
      
      unless OllamaService.check_status
        puts "❌ Failed to start Ollama service".red
        exit 1
      end
    end
    
    # Pull the model
    result = OllamaService.pull_model(model)
    
    if result[:success]
      puts "✅ #{result[:message]}".green
    else
      puts "❌ #{result[:message]}".red
    end
  end
  
  desc "List all Ollama models"
  task :list do
    require 'rainbow/refinement'
    using Rainbow
    
    puts "Listing models in Ollama...".bright.green
    
    # Check if Ollama service is running
    unless OllamaService.check_status
      puts "❌ Ollama service not running".red
      exit 1
    end
    
    # List models
    models = OllamaService.available_models
    
    if models.empty?
      puts "No models found. Pull a model first with: bundle exec rake ollama:pull[model]".yellow
    else
      puts "Available models:".green
      models.each do |model|
        puts "- #{model}"
      end
    end
  end
  
  desc "Run a prompt against an Ollama model"
  task :prompt, [:model, :prompt] do |_, args|
    require 'rainbow/refinement'
    using Rainbow
    
    model = args[:model] || ENV.fetch('OLLAMA_MODEL', 'llama3:8b')
    prompt = args[:prompt] || "What card represents new beginnings in tarot?"
    
    puts "Sending prompt to #{model} in Ollama...".bright.green
    puts "Prompt: #{prompt}"
    
    # Check if Ollama service is running
    unless OllamaService.check_status
      puts "❌ Ollama service not running".red
      exit 1
    end
    
    # Generate response
    puts "Generating response...".cyan
    start_time = Time.now
    
    response = OllamaService.generate_response(model, prompt)
    
    duration = Time.now - start_time
    
    if response[:error]
      puts "❌ Error: #{response[:message]}".red
    else
      puts "✅ Response received (#{duration.round(2)}s):".green
      puts "---"
      puts response["response"]
      puts "---"
      puts "Tokens: #{(response["prompt_eval_count"] || 0) + (response["eval_count"] || 0)}"
    end
  end
  
  desc "Deploy Ollama service to AWS"
  task :deploy, [:environment] do |_, args|
    require 'rainbow/refinement'
    using Rainbow
    
    env = args[:environment] || 'staging'
    
    puts "Deploying Ollama service to #{env}...".bright.green
    
    # Deploy infrastructure using Pulumi
    puts "Deploying infrastructure..."
    system("bundle exec rake pulumi:up[#{env},llm.yaml]")
    
    # Deploy Ollama service using Kamal
    puts "Deploying Ollama service..."
    system("bundle exec rake deploy:ollama[#{env}]")
    
    puts "✅ Ollama service deployed to #{env}".green
  end
  
  desc "Setup Ollama environment"
  task :setup do
    require 'rainbow/refinement'
    using Rainbow
    
    puts "Setting up Ollama environment...".bright.green
    
    # Start Ollama service
    puts "Starting Ollama service..."
    system("docker compose up -d ollama")
    
    # Wait for service to start
    puts "Waiting for Ollama service to start..."
    30.times do
      break if OllamaService.check_status
      print "."
      sleep 1
    end
    puts
    
    unless OllamaService.check_status
      puts "❌ Failed to start Ollama service".red
      exit 1
    end
    
    # Pull default model
    model = ENV.fetch('OLLAMA_MODEL', 'llama3:8b')
    puts "Pulling default model #{model}..."
    
    result = OllamaService.pull_model(model)
    
    if result[:success]
      puts "✅ #{result[:message]}".green
    else
      puts "❌ #{result[:message]}".red
    end
    
    # Set environment variables
    puts "Setting OLLAMA_API_HOST environment variable..."
    if File.exist?('.env')
      env_content = File.read('.env')
      unless env_content.include?('OLLAMA_API_HOST')
        File.open('.env', 'a') do |f|
          f.puts "\n# Ollama configuration"
          f.puts "OLLAMA_API_HOST=http://ollama:11434"
          f.puts "OLLAMA_MODEL=#{model}"
        end
      end
    end
    
    puts "✅ Ollama environment setup complete".green
    puts "You can now use Ollama for LLM inference"
    puts "API endpoint: http://localhost:11434"
    puts "Available commands:"
    puts "- bundle exec rake ollama:list         # List available models"
    puts "- bundle exec rake ollama:pull[model]  # Pull a new model"
    puts "- bundle exec rake ollama:prompt[model,prompt] # Test a prompt"
  end
  
  desc "Test sending prompt to LLM"
  task :test, [:prompt] => :environment do |_, args|
    require 'rainbow/refinement'
    using Rainbow
    
    prompt = args[:prompt] || "What card represents new beginnings in tarot?"
    
    puts "Testing LLM with prompt: #{prompt}".bright.green
    
    # Get direct provider
    provider = LlmProviderFactory.get_provider(:ollama)
    
    begin
      puts "Generating response..."
      start_time = Time.now
      result = provider.generate_response(prompt)
      duration = Time.now - start_time
      
      if result[:error]
        puts "❌ Error: #{result[:error]} - #{result[:message]}".red
      else
        puts "✅ Response received (#{duration.round(2)}s):".green
        puts "---"
        puts result[:content][0..300] + (result[:content].length > 300 ? "..." : "")
        puts "---"
        puts "Model: #{result[:model]}"
      end
    rescue => e
      puts "❌ Test failed: #{e.message}".red
    end
  end
  
  desc "Help: Show all available commands"
  task :help do
    puts "Available ollama tasks:"
    puts "  rake ollama:setup           # Setup Ollama environment"
    puts "  rake ollama:pull[model]     # Pull a model (default: llama3:8b)"
    puts "  rake ollama:list            # List all models"
    puts "  rake ollama:prompt[model,prompt] # Run a prompt against a model"
    puts "  rake ollama:test[prompt]    # Test the LLM integration"
    puts "  rake ollama:deploy[env]     # Deploy Ollama service to AWS"
    puts "  rake ollama:help            # Show this help message"
  end
end 