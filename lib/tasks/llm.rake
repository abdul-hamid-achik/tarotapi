namespace :llm do
  desc "initialize llm models"
  task setup: :environment do
    puts "setting up llm models..."
    
    llm_path = ENV.fetch('LOCAL_LLM_PATH', '/opt/llama.cpp/main')
    model_path = ENV.fetch('LOCAL_LLM_MODEL', '/opt/llama.cpp/models/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf')
    
    if File.exist?(llm_path)
      puts "✅ llama.cpp binary found at #{llm_path}"
    else
      puts "❌ llama.cpp binary not found at #{llm_path}"
    end
    
    if File.exist?(model_path)
      puts "✅ model found at #{model_path}"
      
      # Get model size
      size_mb = File.size(model_path) / (1024 * 1024)
      puts "  model size: #{size_mb} MB"
    else
      puts "❌ model not found at #{model_path}"
    end
    
    # Show current environment settings
    puts "\nLLM Configuration:"
    puts "- DEFAULT_LLM_MODEL: #{ENV.fetch('DEFAULT_LLM_MODEL', 'gpt-4o-mini')} (default model)"
    puts "- PREMIUM_LLM_MODEL: #{ENV.fetch('PREMIUM_LLM_MODEL', 'claude-3-5-sonnet-v2@20241022')} (premium tier)"
    puts "- PROFESSIONAL_LLM_MODEL: #{ENV.fetch('PROFESSIONAL_LLM_MODEL', 'claude-3-7-sonnet@20250219')} (professional tier)"
    puts "- ENABLE_PROFESSIONAL_TIER: #{ENV.fetch('ENABLE_PROFESSIONAL_TIER', 'false')} (for premium users)"
  end
  
  desc "test local llm with a simple prompt"
  task test: :environment do
    puts "testing local llm..."
    
    service = LocalLlmService.new
    prompt = "What card represents new beginnings in tarot?"
    
    puts "sending prompt: '#{prompt}'"
    puts "generating response..."
    
    response = service.generate_response(prompt)
    
    if response[:error]
      puts "❌ error: #{response[:error]} - #{response[:message]}"
    else
      puts "✅ response received:"
      puts "---"
      puts response[:content]
      puts "---"
      puts "tokens: #{response[:tokens][:total]} (prompt: #{response[:tokens][:prompt]}, completion: #{response[:tokens][:completion]})"
    end
  end
  
  desc "update llm call limits for all users"
  task :update_limits, [:limit] => :environment do |_, args|
    limit = args[:limit]&.to_i || abort("limit required")
    
    puts "updating llm call limits for all users to #{limit}..."
    
    if ReadingQuota.table_exists?
      count = ReadingQuota.update_all(llm_calls_limit: limit)
      puts "✅ updated #{count} user quotas to #{limit} llm calls per month"
    else
      puts "❌ reading_quotas table doesn't exist"
    end
  end
  
  desc "check llm usage across all users"
  task check_usage: :environment do
    puts "checking llm usage across all users..."
    
    if ReadingQuota.table_exists?
      total_calls = ReadingQuota.sum(:llm_calls_this_month)
      avg_calls = ReadingQuota.average(:llm_calls_this_month)&.round(2) || 0
      max_calls = ReadingQuota.maximum(:llm_calls_this_month) || 0
      
      puts "total llm calls this month: #{total_calls}"
      puts "average calls per user: #{avg_calls}"
      puts "maximum calls by a single user: #{max_calls}"
      
      # Show top 5 users by usage
      top_users = ReadingQuota.includes(:user)
                             .order(llm_calls_this_month: :desc)
                             .limit(5)
      
      if top_users.any?
        puts "\ntop 5 users by llm usage:"
        top_users.each do |quota|
          puts "  #{quota.user.email}: #{quota.llm_calls_this_month} calls (#{quota.llm_calls_remaining} remaining)"
        end
      end
      
      # Check for users approaching or exceeding limits
      close_to_limit = ReadingQuota.where("llm_calls_this_month > (llm_calls_limit * 0.8)")
                                 .includes(:user)
      
      if close_to_limit.any?
        puts "\nusers approaching or exceeding limits:"
        close_to_limit.each do |quota|
          status = quota.llm_calls_exceeded? ? "❌ EXCEEDED" : 
                   quota.llm_calls_almost_exceeded? ? "⚠️ APPROACHING" : "✅ OK"
          puts "  #{status} | #{quota.user.email}: #{quota.llm_calls_this_month}/#{quota.llm_calls_limit} (#{quota.llm_calls_remaining} remaining)"
        end
      end
    else
      puts "❌ reading_quotas table doesn't exist"
    end
  end
  
  desc "reset llm call counters for all users"
  task reset_counters: :environment do
    puts "resetting llm call counters..."
    
    if ReadingQuota.table_exists?
      count = ReadingQuota.update_all(llm_calls_this_month: 0)
      puts "✅ reset llm call counters for #{count} users"
    else
      puts "❌ reading_quotas table doesn't exist"
    end
  end
  
  desc "test both local and cloud llm models"
  task test_all: :environment do
    puts "testing hybrid llm setup..."
    
    # Check if OpenAI key is set
    if ENV["OPENAI_API_KEY"].nil?
      puts "⚠️ OPENAI_API_KEY not set, cloud models will not work"
    else
      puts "✅ OPENAI_API_KEY found"
    end
    
    prompt = "What card represents new beginnings in tarot?"
    
    # Test local model
    puts "\n== LOCAL MODEL TEST =="
    service = LocalLlmService.new
    
    puts "sending prompt: '#{prompt}'"
    puts "generating response with local model..."
    
    local_response = service.generate_response(prompt)
    
    if local_response[:error]
      puts "❌ error: #{local_response[:error]} - #{local_response[:message]}"
    else
      puts "✅ local response received:"
      puts "---"
      puts local_response[:content]
      puts "---"
      puts "model: #{local_response[:model]}"
      puts "tokens: #{local_response[:tokens][:total]} (prompt: #{local_response[:tokens][:prompt]}, completion: #{local_response[:tokens][:completion]})"
    end
    
    # Only test cloud model if API key is set
    if ENV["OPENAI_API_KEY"]
      puts "\n== CLOUD MODEL TEST =="
      # Create a mock premium user
      mock_user = Struct.new(:subscription_status, :subscription_plan).new("active", Struct.new(:name).new("premium"))
      cloud_service = HybridLlmService.new(mock_user)
      
      puts "sending prompt: '#{prompt}'"
      puts "generating response with cloud model..."
      
      cloud_response = cloud_service.generate_response(prompt)
      
      if cloud_response[:error]
        puts "❌ error: #{cloud_response[:error]} - #{cloud_response[:message]}"
      else
        puts "✅ cloud response received:"
        puts "---"
        puts cloud_response[:content]
        puts "---"
        puts "model: #{cloud_response[:model]}"
        puts "tokens: #{cloud_response[:tokens][:total]} (prompt: #{cloud_response[:tokens][:prompt]}, completion: #{cloud_response[:tokens][:completion]})"
      end
    end
    
    puts "\n== COMPARISON =="
    puts "Free tier users get: Local TinyLlama model (~550MB)"
    puts "Premium tier users get: OpenAI GPT models (cloud API)" 
  end
  
  desc "test multiple provider llm models"
  task test_providers: :environment do
    puts "testing providers setup..."
    
    # Check API keys for each provider
    if ENV["OPENAI_API_KEY"].nil?
      puts "⚠️ OPENAI_API_KEY not set, OpenAI models will not work"
    else
      puts "✅ OPENAI_API_KEY found"
    end
    
    if ENV["ANTHROPIC_API_KEY"].nil?
      puts "⚠️ ANTHROPIC_API_KEY not set, Claude models will not work"
    else
      puts "✅ ANTHROPIC_API_KEY found"
    end
    
    if ENV["OPENROUTER_API_KEY"].nil?
      puts "⚠️ OPENROUTER_API_KEY not set, OpenRouter models will not work"
    else
      puts "✅ OPENROUTER_API_KEY found"
    end
    
    prompt = "Interpret The Fool, The Hanged Man, and The Tower cards in a relationship spread."
    
    # Test multiple providers if keys are available
    providers = []
    providers << :openai if ENV["OPENAI_API_KEY"]
    providers << :anthropic if ENV["ANTHROPIC_API_KEY"] 
    providers << :openrouter if ENV["OPENROUTER_API_KEY"]
    
    if providers.empty?
      puts "❌ No provider API keys found. Skipping cloud model tests."
    else
      puts "Testing #{providers.size} cloud providers with environment-configured models..."
      
      # Display current model configuration
      puts "\nCurrent model configuration:"
      puts "- Default: #{ENV.fetch('DEFAULT_LLM_MODEL', 'gpt-4o-mini')}"
      puts "- Premium: #{ENV.fetch('PREMIUM_LLM_MODEL', 'claude-3-5-sonnet-v2@20241022')}"
      puts "- Professional: #{ENV.fetch('PROFESSIONAL_LLM_MODEL', 'claude-3-7-sonnet@20250219')}"
      
      # Test each tier
      test_tiers = ["free", "premium", "professional"]
      
      test_tiers.each do |tier|
        if tier == "free"
          puts "\n== FREE TIER (LOCAL MODEL) =="
          service = LocalLlmService.new
          
          puts "sending prompt: '#{prompt}'"
          puts "generating response with local model..."
          
          start_time = Time.now
          response = service.generate_response(prompt)
          duration = Time.now - start_time
          
          if response[:error]
            puts "❌ error: #{response[:error]} - #{response[:message]}"
          else
            puts "✅ local response received (#{duration.round(2)}s):"
            puts "--- FIRST 150 CHARS ---"
            puts response[:content][0..150] + "..."
            puts "------------------------"
            puts "tokens: #{response[:tokens][:total]} (prompt: #{response[:tokens][:prompt]}, completion: #{response[:tokens][:completion]})"
          end
        else
          puts "\n== #{tier.upcase} TIER =="
          
          # Set professional tier env var if testing professional tier
          old_env = ENV["ENABLE_PROFESSIONAL_TIER"]
          ENV["ENABLE_PROFESSIONAL_TIER"] = "true" if tier == "professional"
          
          # Create a mock user for testing
          mock_user = OpenStruct.new(
            subscription_status: "active",
            subscription_plan: OpenStruct.new(name: "premium"),
            reading_quota: nil
          )
          
          # Create service with the tier
          service = HybridLlmService.new(mock_user)
          
          # Get model for this tier
          model = tier == "premium" ? 
                 ENV.fetch('PREMIUM_LLM_MODEL', 'claude-3-5-sonnet-v2@20241022') : 
                 ENV.fetch('PROFESSIONAL_LLM_MODEL', 'claude-3-7-sonnet@20250219')
          
          puts "Testing model: #{model}"
          puts "Sending prompt: '#{prompt}'"
          
          start_time = Time.now
          response = service.generate_response(prompt)
          duration = Time.now - start_time
          
          if response[:error]
            puts "❌ error: #{response[:error]} - #{response[:message]}"
          else
            puts "✅ response received (#{duration.round(2)}s):"
            puts "--- FIRST 150 CHARS ---"
            puts response[:content][0..150].gsub("\n", "\n  ") + "..."
            puts "------------------------"
            puts "model: #{response[:model]}"
            if response[:tokens]
              puts "tokens: #{response[:tokens][:total]} (prompt: #{response[:tokens][:prompt]}, completion: #{response[:tokens][:completion]})"
            end
          end
          
          # Restore env var
          ENV["ENABLE_PROFESSIONAL_TIER"] = old_env
        end
      end
    end
    
    puts "\n== TIER MODEL COMPARISON =="
    puts "🔹 FREE TIER: Local TinyLlama model (~550MB)"
    puts "🔹 PREMIUM TIER: Claude 3.5 Sonnet (latest Anthropic model)"
    puts "🔹 PROFESSIONAL TIER: Claude 3.7 Sonnet (most advanced Anthropic model, 3x quota cost)"
    
    puts "\nQuota multipliers:"
    puts "FREE: 1x"
    puts "PREMIUM: 1x"
    puts "PROFESSIONAL: 3x (counts as 3 calls against quota)"
    
    puts "\nTo change models, set these environment variables:"
    puts "DEFAULT_LLM_MODEL=gpt-4o-mini"
    puts "PREMIUM_LLM_MODEL=claude-3-5-sonnet-v2@20241022"
    puts "PROFESSIONAL_LLM_MODEL=claude-3-7-sonnet@20250219"
    puts "ENABLE_PROFESSIONAL_TIER=true|false"
  end
  
  desc "add required env vars for multi-provider setup"
  task setup_providers: :environment do
    puts "To use multiple LLM providers, add these environment variables:"
    puts
    puts "# OpenAI (for GPT models)"
    puts "OPENAI_API_KEY=your_openai_key"
    puts
    puts "# Anthropic (for Claude models)"
    puts "ANTHROPIC_API_KEY=your_anthropic_key"
    puts
    puts "# OpenRouter (for multiple models through one API)"
    puts "OPENROUTER_API_KEY=your_openrouter_key"
    puts "APP_URL=https://tarotapi.cards"
    puts
    puts "Add these to your .env file for development,"
    puts "or to your GitHub repository secrets and environment variables for production."
    puts
    puts "To update your GitHub secrets:"
    puts "1. Go to your repository settings"
    puts "2. Navigate to Secrets and variables > Actions"
    puts "3. Add the API keys as new secrets"
  end
  
  desc "cleanup unused files"
  task cleanup: :environment do
    puts "cleaning up unused files..."
    
    # Check if model preferences controller exists and remove it
    model_pref_controller = Rails.root.join('app', 'controllers', 'api', 'v1', 'model_preferences_controller.rb')
    if File.exist?(model_pref_controller)
      File.delete(model_pref_controller)
      puts "✅ removed unused model_preferences_controller.rb"
    end
    
    # Other cleanup as needed
    puts "✅ cleanup complete"
  end
  
  desc "update model settings"
  task update_settings: :environment do
    puts "current model settings:"
    puts "- DEFAULT_LLM_MODEL: #{ENV.fetch('DEFAULT_LLM_MODEL', 'gpt-4o-mini')}"
    puts "- PREMIUM_LLM_MODEL: #{ENV.fetch('PREMIUM_LLM_MODEL', 'claude-3-5-sonnet-v2@20241022')}"
    puts "- PROFESSIONAL_LLM_MODEL: #{ENV.fetch('PROFESSIONAL_LLM_MODEL', 'claude-3-7-sonnet@20250219')}"
    puts "- ENABLE_PROFESSIONAL_TIER: #{ENV.fetch('ENABLE_PROFESSIONAL_TIER', 'false')}"
    
    puts "\nmodel details:"
    puts "- claude-3-5-sonnet-v2@20241022: Claude 3.5 Sonnet (latest version) - fast, accurate, and cost-effective"
    puts "- claude-3-7-sonnet@20250219: Claude 3.7 Sonnet - Anthropic's most powerful model with hybrid reasoning"
    puts "- gpt-4o-mini: OpenAI's smaller, faster GPT-4o variant"
    puts "- gpt-4o: OpenAI's multimodal foundation model"
    
    puts "\nto update settings, add these to your .env file or GitHub repository secrets"
  end
end 