class LlmService
  include Singleton

  def initialize
    @client = OpenAI::Client.new(access_token: ENV["OPENAI_API_KEY"])
  end

  def interpret_reading(cards:, positions:, spread_name:, is_reversed: false, question: nil, astrological_context: nil, numerological_context: nil, symbolism_context: nil)
    prompt_context = {
      cards: cards,
      positions: positions,
      spread_name: spread_name,
      is_reversed: is_reversed,
      question: question,
      astrological_context: astrological_context,
      numerological_context: numerological_context,
      symbolism_context: symbolism_context
    }
    
    prompt = PromptService.get_prompt(PromptService::PROMPT_TYPES[:tarot_reading], prompt_context)
    
    response = @client.chat(
      parameters: {
        model: "gpt-4-turbo-preview",
        messages: [
          { role: "system", content: prompt[:system] },
          { role: "user", content: prompt[:user] }
        ],
        temperature: 0.7,
        max_tokens: 1000
      }
    )

    response.dig("choices", 0, "message", "content")
  end
  
  def get_card_meaning(card_name:, is_reversed: false, numerology: nil, arcana_info: nil, symbolism: nil)
    prompt_context = { 
      card_name: card_name,
      is_reversed: is_reversed,
      numerology: numerology,
      arcana_info: arcana_info,
      symbolism: symbolism
    }
    
    prompt = PromptService.get_prompt(PromptService::PROMPT_TYPES[:card_meaning], prompt_context)
    
    response = @client.chat(
      parameters: {
        model: "gpt-4-turbo-preview",
        messages: [
          { role: "system", content: prompt[:system] },
          { role: "user", content: prompt[:user] }
        ],
        temperature: 0.7,
        max_tokens: 800
      }
    )

    response.dig("choices", 0, "message", "content")
  end
  
  def explain_spread(spread_name, positions)
    prompt_context = { 
      spread_name: spread_name,
      positions: positions
    }
    
    prompt = PromptService.get_prompt(PromptService::PROMPT_TYPES[:spread_explanation], prompt_context)
    
    response = @client.chat(
      parameters: {
        model: "gpt-4-turbo-preview",
        messages: [
          { role: "system", content: prompt[:system] },
          { role: "user", content: prompt[:user] }
        ],
        temperature: 0.7,
        max_tokens: 800
      }
    )

    response.dig("choices", 0, "message", "content")
  end
  
  def get_astrological_influence(astrological_context)
    prompt_context = astrological_context
    
    prompt = PromptService.get_prompt(PromptService::PROMPT_TYPES[:astrological_influence], prompt_context)
    
    response = @client.chat(
      parameters: {
        model: "gpt-4-turbo-preview",
        messages: [
          { role: "system", content: prompt[:system] },
          { role: "user", content: prompt[:user] }
        ],
        temperature: 0.7,
        max_tokens: 800
      }
    )

    response.dig("choices", 0, "message", "content")
  end
  
  def get_daily_guidance(card_name, is_reversed = false, numerology = nil)
    prompt_context = { 
      card_name: card_name,
      is_reversed: is_reversed,
      numerology: numerology || NumerologyService.get_card_numerology(card_name)
    }
    
    prompt = PromptService.get_prompt(PromptService::PROMPT_TYPES[:daily_guidance], prompt_context)
    
    response = @client.chat(
      parameters: {
        model: "gpt-4-turbo-preview",
        messages: [
          { role: "system", content: prompt[:system] },
          { role: "user", content: prompt[:user] }
        ],
        temperature: 0.7,
        max_tokens: 500
      }
    )

    response.dig("choices", 0, "message", "content")
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
    
    response = @client.chat(
      parameters: {
        model: "gpt-4-turbo-preview",
        messages: [
          { role: "system", content: prompt[:system] },
          { role: "user", content: prompt[:user] }
        ],
        temperature: 0.7,
        max_tokens: 1000
      }
    )

    response.dig("choices", 0, "message", "content")
  end
  
  def get_numerological_insight(life_path_number:, name_number: nil, birth_date: nil, life_path_meaning: nil)
    prompt_context = {
      life_path_number: life_path_number,
      name_number: name_number,
      birth_date: birth_date,
      life_path_meaning: life_path_meaning
    }
    
    prompt = PromptService.get_prompt(PromptService::PROMPT_TYPES[:numerological_insight], prompt_context)
    
    response = @client.chat(
      parameters: {
        model: "gpt-4-turbo-preview",
        messages: [
          { role: "system", content: prompt[:system] },
          { role: "user", content: prompt[:user] }
        ],
        temperature: 0.7,
        max_tokens: 800
      }
    )

    response.dig("choices", 0, "message", "content")
  end
  
  def get_symbolism_analysis(cards:, symbols:, pattern: nil, is_reading: false)
    prompt_context = {
      cards: cards,
      symbols: symbols,
      pattern: pattern,
      is_reading: is_reading
    }
    
    prompt = PromptService.get_prompt(PromptService::PROMPT_TYPES[:symbolism_analysis], prompt_context)
    
    response = @client.chat(
      parameters: {
        model: "gpt-4-turbo-preview",
        messages: [
          { role: "system", content: prompt[:system] },
          { role: "user", content: prompt[:user] }
        ],
        temperature: 0.7,
        max_tokens: 800
      }
    )

    response.dig("choices", 0, "message", "content")
  end
  
  def get_arcana_explanation(arcana_type:, specific_card: nil)
    prompt_context = {
      arcana_type: arcana_type,
      specific_card: specific_card
    }
    
    prompt = PromptService.get_prompt(PromptService::PROMPT_TYPES[:arcana_explanation], prompt_context)
    
    response = @client.chat(
      parameters: {
        model: "gpt-4-turbo-preview",
        messages: [
          { role: "system", content: prompt[:system] },
          { role: "user", content: prompt[:user] }
        ],
        temperature: 0.7,
        max_tokens: 1000
      }
    )

    response.dig("choices", 0, "message", "content")
  end
end 