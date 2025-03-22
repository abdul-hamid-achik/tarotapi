class HybridLlmService
  attr_reader :user, :quota

  # Model mappings across different providers
  # These will be overridden by environment variables if set
  DEFAULT_CLOUD_MODELS = {
    default: ENV.fetch("DEFAULT_LLM_MODEL", "gpt-4o-mini"),
    premium: ENV.fetch("PREMIUM_LLM_MODEL", "claude-3-5-sonnet-v2@20241022"),
    professional: ENV.fetch("PROFESSIONAL_LLM_MODEL", "claude-3-7-sonnet@20250219")
  }

  # Define quota multipliers for different tiers
  QUOTA_MULTIPLIERS = {
    free: 1,
    premium: 1,
    professional: 3  # Professional tier counts as 3 calls against quota
  }

  # API selection based on model type
  API_PROVIDERS = {
    # OpenAI models
    "gpt-4o-mini" => :openai,
    "gpt-4o" => :openai,

    # Anthropic models
    "claude-3-5-sonnet-v2@20241022" => :anthropic,
    "claude-3-7-sonnet@20250219" => :anthropic,

    # OpenRouter models
    "llama-3-8b" => :openrouter,
    "mistral-large" => :openrouter
  }

  def initialize(user = nil, quota = nil)
    @user = user
    @quota = quota || (user&.reading_quota)
    @subscription_tier = user&.subscription_status == "active" ? user.subscription_plan&.name || "premium" : "free"

    # Check if professional tier is enabled for this user by env var
    @selected_tier = if ENV["ENABLE_PROFESSIONAL_TIER"] == "true" && @subscription_tier == "premium"
                      "professional"
    else
                      @subscription_tier
    end
  end

  def generate_response(prompt, options = {})
    # Track LLM usage if quota is available
    if @quota
      # Get multiplier based on tier
      multiplier = QUOTA_MULTIPLIERS[@selected_tier.to_sym] || 1

      # Check if this would exceed quota
      if would_exceed_quota?(multiplier)
        Rails.logger.warn("LLM call quota exceeded for user ##{@quota.user_id}")
        return { error: "llm_quota_exceeded", message: "You have exceeded your monthly LLM call limit" }
      end

      @quota.increment_llm_call!(multiplier)
    end

    # Select model based on subscription tier
    if free_tier?
      generate_local_response(prompt, options)
    else
      generate_cloud_response(prompt, options)
    end
  end

  # Get available models for the user's tier
  def available_models
    if free_tier?
      [ "local-tinyllama" ]
    elsif premium_tier?
      [ "gpt-4o-mini", "claude-3-5-sonnet-v2@20241022" ]
    elsif professional_tier?
      [ "gpt-4o-mini", "claude-3-5-sonnet-v2@20241022", "claude-3-7-sonnet@20250219", "llama-3-8b", "mistral-large" ]
    else
      [ "local-tinyllama" ]
    end
  end

  private

  def would_exceed_quota?(multiplier)
    return false unless @quota
    return false if unlimited_tier?

    @quota.llm_calls_this_month + multiplier > @quota.llm_calls_limit
  end

  def free_tier?
    @subscription_tier == "free" || @subscription_tier.nil?
  end

  def premium_tier?
    @subscription_tier == "premium" && @selected_tier != "professional"
  end

  def professional_tier?
    @selected_tier == "professional"
  end

  def unlimited_tier?
    @subscription_tier == "unlimited"
  end

  def generate_local_response(prompt, options)
    Rails.logger.info("Using local LLM for free tier user")
    service = LocalLlmService.new(@quota)
    service.generate_response(prompt, options)
  end

  def generate_cloud_response(prompt, options)
    # Determine cloud model based on tier
    cloud_model = options[:model] || DEFAULT_CLOUD_MODELS[@selected_tier.to_sym] || DEFAULT_CLOUD_MODELS[:default]

    Rails.logger.info("Using #{cloud_model} for #{@selected_tier} tier user")

    # Default options for cloud models
    opts = {
      temperature: 0.7,
      max_tokens: 500,
      model: cloud_model,
      system_prompt: "You are a helpful tarot reading assistant."
    }.merge(options)

    begin
      # Call appropriate API based on model
      start_time = Time.now
      provider = API_PROVIDERS[cloud_model] || :openai

      response = case provider
      when :openai
                   openai_request(prompt, opts)
      when :anthropic
                   anthropic_request(prompt, opts)
      when :openrouter
                   openrouter_request(prompt, opts)
      else
                   openai_request(prompt, opts) # Default to OpenAI
      end

      duration = Time.now - start_time

      Rails.logger.info("Cloud LLM request completed in #{duration.round(2)}s using #{cloud_model}")

      response
    rescue => e
      Rails.logger.error("Cloud LLM error: #{e.message}")

      # Fallback to local model if cloud fails
      Rails.logger.info("Falling back to local LLM due to cloud API error")
      generate_local_response(prompt, options)
    end
  end

  def openai_request(prompt, opts)
    Rails.logger.info("Using OpenAI API")

    # Configure OpenAI client
    client = OpenAI::Client.new(access_token: ENV.fetch("OPENAI_API_KEY"))

    # Format the messages for ChatGPT
    messages = [
      { role: "system", content: opts[:system_prompt] },
      { role: "user", content: prompt }
    ]

    # Make the API request
    response = client.chat(
      parameters: {
        model: opts[:model],
        messages: messages,
        temperature: opts[:temperature],
        max_tokens: opts[:max_tokens]
      }
    )

    if response["error"]
      { error: "cloud_llm_error", message: response["error"]["message"] }
    else
      {
        content: response["choices"][0]["message"]["content"],
        model: opts[:model],
        tokens: {
          prompt: response["usage"]["prompt_tokens"],
          completion: response["usage"]["completion_tokens"],
          total: response["usage"]["total_tokens"]
        }
      }
    end
  end

  def anthropic_request(prompt, opts)
    Rails.logger.info("Using Anthropic API")

    require "net/http"
    require "uri"
    require "json"

    uri = URI.parse("https://api.anthropic.com/v1/messages")
    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request["X-Api-Key"] = ENV.fetch("ANTHROPIC_API_KEY")
    request["Anthropic-Version"] = "2023-06-01"

    request.body = {
      model: opts[:model],
      messages: [
        { role: "user", content: prompt }
      ],
      system: opts[:system_prompt],
      max_tokens: opts[:max_tokens]
    }.to_json

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    parsed_response = JSON.parse(response.body)

    if response.code != "200"
      { error: "anthropic_api_error", message: parsed_response["error"]["message"] }
    else
      {
        content: parsed_response["content"][0]["text"],
        model: opts[:model],
        tokens: {
          prompt: parsed_response["usage"]["input_tokens"],
          completion: parsed_response["usage"]["output_tokens"],
          total: parsed_response["usage"]["input_tokens"] + parsed_response["usage"]["output_tokens"]
        }
      }
    end
  end

  def openrouter_request(prompt, opts)
    Rails.logger.info("Using OpenRouter API")

    require "net/http"
    require "uri"
    require "json"

    uri = URI.parse("https://openrouter.ai/api/v1/chat/completions")
    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request["Authorization"] = "Bearer #{ENV.fetch("OPENROUTER_API_KEY")}"
    request["HTTP-Referer"] = ENV.fetch("APP_URL", "https://tarotapi.cards")

    request.body = {
      model: opts[:model],
      messages: [
        { role: "system", content: opts[:system_prompt] },
        { role: "user", content: prompt }
      ],
      temperature: opts[:temperature],
      max_tokens: opts[:max_tokens]
    }.to_json

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    parsed_response = JSON.parse(response.body)

    if !parsed_response["choices"] || parsed_response["error"]
      { error: "openrouter_api_error", message: parsed_response["error"] || "Unknown error" }
    else
      {
        content: parsed_response["choices"][0]["message"]["content"],
        model: parsed_response["model"],
        tokens: {
          prompt: parsed_response["usage"]["prompt_tokens"],
          completion: parsed_response["usage"]["completion_tokens"],
          total: parsed_response["usage"]["total_tokens"]
        }
      }
    end
  end
end
