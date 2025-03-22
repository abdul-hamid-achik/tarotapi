class LocalLlmService
  def initialize(quota = nil)
    @quota = quota
    @client = OpenAI::Client.new(
      access_token: ENV.fetch("OPENAI_API_KEY"),
      request_timeout: 60
    )
  end

  def generate_response(prompt, options = {})
    # Default options
    opts = {
      temperature: 0.7,
      max_tokens: 256,
      system_prompt: "You are a helpful tarot reading assistant."
    }.merge(options)

    # Track LLM usage if quota provided
    if @quota
      if @quota.llm_calls_exceeded?
        Rails.logger.warn("LLM call quota exceeded for user ##{@quota.user_id}")
        return { error: "llm_quota_exceeded", message: "You have exceeded your monthly LLM call limit" }
      end

      @quota.increment_llm_call!
    end

    # Format messages for GPT
    messages = [
      { role: "system", content: opts[:system_prompt] },
      { role: "user", content: prompt }
    ]

    start_time = Time.now

    begin
      # Use GPT-3.5-turbo for free tier (much cheaper than GPT-4)
      response = @client.chat(
        parameters: {
          model: "gpt-3.5-turbo",
          messages: messages,
          temperature: opts[:temperature],
          max_tokens: opts[:max_tokens]
        }
      )

      duration = Time.now - start_time
      Rails.logger.info("LLM request completed in #{duration.round(2)}s")

      if response["error"]
        Rails.logger.error("LLM error: #{response["error"]["message"]}")
        { error: "llm_error", message: response["error"]["message"] }
      else
        {
          content: response["choices"][0]["message"]["content"].strip,
          model: "gpt-3.5-turbo",
          tokens: {
            prompt: response["usage"]["prompt_tokens"],
            completion: response["usage"]["completion_tokens"],
            total: response["usage"]["total_tokens"]
          }
        }
      end
    rescue => e
      Rails.logger.error("LLM error: #{e.message}")
      { error: "llm_error", message: e.message }
    end
  end
end
