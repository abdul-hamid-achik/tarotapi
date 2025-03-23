module LlmProviders
  class AnthropicProvider < BaseProvider
    def initialize(quota = nil)
      super(quota)
      @client = initialize_client
    end

    def generate_response(prompt, options = {})
      # Default options
      opts = {
        temperature: 0.7,
        max_tokens: 500,
        system_prompt: "You are a helpful tarot reading assistant.",
        model: ENV.fetch("PREMIUM_LLM_MODEL", "claude-3-5-sonnet-v2@20241022")
      }.merge(options)

      return format_error("llm_quota_exceeded", "You have exceeded your monthly LLM call limit") unless track_usage

      start_time = Time.now

      begin
        response = @client.complete(
          prompt: format_prompt_for_anthropic(opts[:system_prompt], prompt),
          model: opts[:model],
          max_tokens: opts[:max_tokens],
          temperature: opts[:temperature]
        )

        duration = Time.now - start_time
        Rails.logger.info("Anthropic LLM request completed in #{duration.round(2)}s")

        # Parse response
        format_response(
          response["content"][0]["text"],
          opts[:model],
          {
            # Anthropic doesn't provide token counts in the same way
            prompt: 0,
            completion: 0,
            total: 0
          }
        )
      rescue => e
        Rails.logger.error("Anthropic LLM error: #{e.message}")
        format_error("llm_error", e.message)
      end
    end

    def generate_streaming_response(prompt, options = {}, &block)
      # Default options
      opts = {
        temperature: 0.7,
        max_tokens: 500,
        system_prompt: "You are a helpful tarot reading assistant.",
        model: ENV.fetch("PREMIUM_LLM_MODEL", "claude-3-5-sonnet-v2@20241022")
      }.merge(options)

      return format_error("llm_quota_exceeded", "You have exceeded your monthly LLM call limit") unless track_usage

      begin
        full_response = ""

        @client.stream(
          prompt: format_prompt_for_anthropic(opts[:system_prompt], prompt),
          model: opts[:model],
          max_tokens: opts[:max_tokens],
          temperature: opts[:temperature]
        ) do |chunk|
          content = chunk["content"][0]["text"] rescue nil
          if content
            delta = content.sub(full_response, "")
            full_response = content
            yield delta if block_given?
          end
        end

        format_response(full_response, opts[:model])
      rescue => e
        Rails.logger.error("Anthropic streaming LLM error: #{e.message}")
        format_error("llm_error", e.message)
      end
    end

    def available_models
      [
        "claude-3-5-sonnet-v2@20241022",
        "claude-3-7-sonnet@20250219",
        "claude-3-haiku"
      ]
    end

    private

    def initialize_client
      if Rails.env.test?
        # Use a mock implementation for testing
        require_relative "../../../spec/support/langchain_mock"
      else
        require "langchain"
      end

      Langchain::LLM::Anthropic.new(api_key: ENV.fetch("ANTHROPIC_API_KEY"))
    end

    def format_prompt_for_anthropic(system_prompt, user_prompt)
      {
        system: system_prompt,
        messages: [
          { role: "user", content: user_prompt }
        ]
      }
    end
  end
end
