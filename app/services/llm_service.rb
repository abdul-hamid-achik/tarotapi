class LlmService
  include Singleton

  # Tier configurations
  QUOTA_MULTIPLIERS = {
    free: 1,
    premium: 2,
    professional: 3
  }.freeze

  # Default models by tier
  DEFAULT_MODELS = {
    free: ENV.fetch("OLLAMA_MODEL", "llama3:8b"),
    premium: ENV.fetch("PREMIUM_LLM_MODEL", "claude-3-5-sonnet-v2@20241022"),
    professional: ENV.fetch("PROFESSIONAL_LLM_MODEL", "claude-3-7-sonnet@20250219")
  }.freeze

  def initialize
    # Initialize with no user - will be set per-request
    @user = nil
    @quota = nil
  end

  # Set the current user context
  def set_user(user)
    @user = user
    @quota = user&.reading_quota
    @tier = determine_tier(user)
  end

  # Main method to generate a response
  def generate_response(prompt, options = {})
    # Default to free tier if no user set
    tier = @tier || :free

    # Select model based on tier unless specifically requested
    model = options[:model] || DEFAULT_MODELS[tier]

    # Track usage if quota available
    if @quota
      multiplier = QUOTA_MULTIPLIERS[tier] || 1

      if @quota.llm_calls_this_month + multiplier > @quota.llm_calls_limit
        return { error: "llm_quota_exceeded", message: "You have exceeded your monthly LLM call limit" }
      end

      @quota.increment_llm_call!(multiplier)
    end

    # Get provider for this model
    provider = LlmProviderFactory.get_provider_for_model(model, @quota)

    # Generate response
    Rails.logger.info("Using #{model} via #{provider.class.name}")
    provider.generate_response(prompt, options.merge(model: model))
  end

  # Stream a response
  def generate_streaming_response(prompt, options = {}, &block)
    # Default to free tier if no user set
    tier = @tier || :free

    # Select model based on tier unless specifically requested
    model = options[:model] || DEFAULT_MODELS[tier]

    # Track usage if quota available
    if @quota
      multiplier = QUOTA_MULTIPLIERS[tier] || 1

      if @quota.llm_calls_this_month + multiplier > @quota.llm_calls_limit
        return { error: "llm_quota_exceeded", message: "You have exceeded your monthly LLM call limit" }
      end

      @quota.increment_llm_call!(multiplier)
    end

    # Get provider for this model
    provider = LlmProviderFactory.get_provider_for_model(model, @quota)

    # Generate streaming response
    Rails.logger.info("Streaming from #{model} via #{provider.class.name}")
    provider.generate_streaming_response(prompt, options.merge(model: model), &block)
  end

  # Get available models for the user's tier
  def available_models(tier = nil)
    tier ||= @tier || :free

    case tier
    when :free
      provider = LlmProviderFactory.get_provider(:ollama)
      provider.available_models
    when :premium
      [ "gpt-4o-mini", "claude-3-5-sonnet-v2@20241022" ]
    when :professional
      [ "gpt-4o-mini", "claude-3-5-sonnet-v2@20241022", "claude-3-7-sonnet@20250219", "llama3:8b", "mistral" ]
    else
      provider = LlmProviderFactory.get_provider(:ollama)
      provider.available_models
    end
  end

  # Tarot-specific methods follow

  def interpret_reading(cards:, positions:, spread_name:, is_reversed: false, question: nil, astrological_context: nil, numerological_context: nil, symbolism_context: nil)
    prompt = build_reading_prompt(cards, positions, spread_name, is_reversed, question, astrological_context, numerological_context, symbolism_context)

    # For interpretations, use premium model if available
    model = @tier == :free ? DEFAULT_MODELS[:free] : "gpt-4o"

    response = generate_response(prompt, {
      model: model,
      system_prompt: "You are an expert tarot reader with deep knowledge of symbolism and card meanings.",
      temperature: 0.7,
      max_tokens: 1000
    })

    response[:content]
  end

  def interpret_reading_streaming(cards:, positions:, spread_name:, is_reversed: false, question: nil, astrological_context: nil, numerological_context: nil, symbolism_context: nil, &block)
    prompt = build_reading_prompt(cards, positions, spread_name, is_reversed, question, astrological_context, numerological_context, symbolism_context)

    # For interpretations, use premium model if available
    model = @tier == :free ? DEFAULT_MODELS[:free] : "gpt-4o"

    full_response = ""

    generate_streaming_response(prompt, {
      model: model,
      system_prompt: "You are an expert tarot reader with deep knowledge of symbolism and card meanings.",
      temperature: 0.7,
      max_tokens: 1000
    }) do |chunk|
      full_response += chunk
      yield chunk if block_given?
    end

    full_response
  end

  # Other tarot interpretation methods can remain similar to before

  def get_card_meaning(card_name:, is_reversed: false, numerology: nil, arcana_info: nil, symbolism: nil)
    prompt_context = {
      card_name: card_name,
      is_reversed: is_reversed,
      numerology: numerology,
      arcana_info: arcana_info,
      symbolism: symbolism
    }

    prompt = PromptService.get_prompt(PromptService::PROMPT_TYPES[:card_meaning], prompt_context)

    response = generate_response(prompt[:user], {
      model: @tier == :free ? DEFAULT_MODELS[:free] : "gpt-4o",
      system_prompt: prompt[:system],
      temperature: 0.7,
      max_tokens: 800
    })

    response[:content]
  end

  def explain_spread(spread_name, positions)
    prompt_context = {
      spread_name: spread_name,
      positions: positions
    }

    prompt = PromptService.get_prompt(PromptService::PROMPT_TYPES[:spread_explanation], prompt_context)

    response = generate_response(prompt[:user], {
      model: @tier == :free ? DEFAULT_MODELS[:free] : "gpt-4o",
      system_prompt: prompt[:system],
      temperature: 0.7,
      max_tokens: 800
    })

    response[:content]
  end

  def get_astrological_influence(astrological_context)
    prompt_context = astrological_context

    prompt = PromptService.get_prompt(PromptService::PROMPT_TYPES[:astrological_influence], prompt_context)

    response = generate_response(prompt[:user], {
      model: @tier == :free ? DEFAULT_MODELS[:free] : "gpt-4o",
      system_prompt: prompt[:system],
      temperature: 0.7,
      max_tokens: 800
    })

    response[:content]
  end

  def get_daily_guidance(card_name, is_reversed = false, numerology = nil)
    prompt_context = {
      card_name: card_name,
      is_reversed: is_reversed,
      numerology: numerology || NumerologyService.get_card_numerology(card_name)
    }

    prompt = PromptService.get_prompt(PromptService::PROMPT_TYPES[:daily_guidance], prompt_context)

    response = generate_response(prompt[:user], {
      model: @tier == :free ? DEFAULT_MODELS[:free] : "gpt-4o",
      system_prompt: prompt[:system],
      temperature: 0.7,
      max_tokens: 500
    })

    response[:content]
  end

  def get_specialized_reading(type, context)
    prompt_type = case type
    when "spiritual"
      PromptService::PROMPT_TYPES[:spiritual_growth]
    when "relationship"
      PromptService::PROMPT_TYPES[:relationship_advice]
    when "career"
      PromptService::PROMPT_TYPES[:career_guidance]
    when "personal"
      PromptService::PROMPT_TYPES[:personal_development]
    else
      PromptService::PROMPT_TYPES[:tarot_reading]
    end

    prompt = PromptService.get_prompt(prompt_type, context)

    response = generate_response(prompt[:user], {
      model: @tier == :free ? DEFAULT_MODELS[:free] : "gpt-4o",
      system_prompt: prompt[:system],
      temperature: 0.7,
      max_tokens: 1000
    })

    response[:content]
  end

  def get_numerological_insight(life_path_number:, name_number: nil, birth_date: nil, life_path_meaning: nil)
    prompt_context = {
      life_path_number: life_path_number,
      name_number: name_number,
      birth_date: birth_date,
      life_path_meaning: life_path_meaning
    }

    prompt = PromptService.get_prompt(PromptService::PROMPT_TYPES[:numerological_insight], prompt_context)

    response = generate_response(prompt[:user], {
      model: @tier == :free ? DEFAULT_MODELS[:free] : "gpt-4o",
      system_prompt: prompt[:system],
      temperature: 0.7,
      max_tokens: 800
    })

    response[:content]
  end

  def get_symbolism_analysis(cards:, symbols:, pattern: nil, is_reading: false)
    prompt_context = {
      cards: cards,
      symbols: symbols,
      pattern: pattern,
      is_reading: is_reading
    }

    prompt = PromptService.get_prompt(PromptService::PROMPT_TYPES[:symbolism_analysis], prompt_context)

    response = generate_response(prompt[:user], {
      model: @tier == :free ? DEFAULT_MODELS[:free] : "gpt-4o",
      system_prompt: prompt[:system],
      temperature: 0.7,
      max_tokens: 800
    })

    response[:content]
  end

  def get_arcana_explanation(arcana_type:, specific_card: nil)
    prompt_context = {
      arcana_type: arcana_type,
      specific_card: specific_card
    }

    prompt = PromptService.get_prompt(PromptService::PROMPT_TYPES[:arcana_explanation], prompt_context)

    response = generate_response(prompt[:user], {
      model: @tier == :free ? DEFAULT_MODELS[:free] : "gpt-4o",
      system_prompt: prompt[:system],
      temperature: 0.7,
      max_tokens: 1000
    })

    response[:content]
  end

  private

  def determine_tier(user)
    return :free unless user

    subscription_status = user.subscription_status
    subscription_plan = user.subscription_plan&.name

    if subscription_status == "active"
      case subscription_plan
      when "professional"
        :professional
      when "premium"
        ENV.fetch("ENABLE_PROFESSIONAL_TIER", "false") == "true" ? :professional : :premium
      else
        :free
      end
    else
      :free
    end
  end

  def build_reading_prompt(cards, positions, spread_name, is_reversed, question, astrological_context, numerological_context, symbolism_context)
    # Build a detailed prompt for tarot reading
    prompt = "Provide a tarot reading interpretation for the following spread:\n"
    prompt += "Spread: #{spread_name}\n\n"
    prompt += "Question: #{question}\n\n" if question.present?

    # Add cards and positions
    prompt += "Cards drawn:\n"
    cards.each_with_index do |card, i|
      position = positions[i]
      reversed = is_reversed ? " (reversed)" : ""
      prompt += "- #{position}: #{card}#{reversed}\n"
    end

    # Add additional context if available
    if astrological_context.present?
      prompt += "\nAstrological context:\n#{astrological_context}\n"
    end

    if numerological_context.present?
      prompt += "\nNumerological context:\n#{numerological_context}\n"
    end

    if symbolism_context.present?
      prompt += "\nSymbolism context:\n#{symbolism_context}\n"
    end

    prompt
  end
end
