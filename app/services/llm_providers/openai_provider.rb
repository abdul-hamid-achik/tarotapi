module LlmProviders
  class OpenaiProvider < BaseProvider
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
        model: ENV.fetch("OPENAI_MODEL", "gpt-4o")
      }.merge(options)

      return format_error("llm_quota_exceeded", "You have exceeded your monthly LLM call limit") unless track_usage

      begin
        response = @client.complete(
          prompt: {
            system: opts[:system_prompt],
            messages: [{ role: "user", content: prompt }]
          },
          model: opts[:model],
          max_tokens: opts[:max_tokens],
          temperature: opts[:temperature]
        )

        # Parse response
        format_response(
          response.dig("choices", 0, "message", "content"),
          opts[:model],
          {
            prompt: response.dig("usage", "prompt_tokens") || 0,
            completion: response.dig("usage", "completion_tokens") || 0,
            total: response.dig("usage", "total_tokens") || 0
          }
        )
      rescue => e
        Rails.logger.error("OpenAI LLM error: #{e.message}")
        format_error("llm_error", e.message)
      end
    end

    def generate_streaming_response(prompt, options = {}, &block)
      # Default options
      opts = {
        temperature: 0.7,
        max_tokens: 500,
        system_prompt: "You are a helpful tarot reading assistant.",
        model: ENV.fetch("OPENAI_MODEL", "gpt-4o")
      }.merge(options)

      return format_error("llm_quota_exceeded", "You have exceeded your monthly LLM call limit") unless track_usage

      begin
        full_response = ""

        @client.stream(
          prompt: {
            system: opts[:system_prompt],
            messages: [{ role: "user", content: prompt }]
          },
          model: opts[:model],
          max_tokens: opts[:max_tokens],
          temperature: opts[:temperature]
        ) do |chunk|
          content = chunk.dig("choices", 0, "delta", "content")
          if content
            full_response += content
            yield content if block_given?
          end
        end

        format_response(full_response, opts[:model])
      rescue => e
        Rails.logger.error("OpenAI streaming LLM error: #{e.message}")
        format_error("llm_error", e.message)
      end
    end

    def available_models
      [
        "gpt-4o",
        "gpt-4-turbo",
        "gpt-3.5-turbo"
      ]
    end

    private

    def initialize_client
      if Rails.env.test?
        # Use a mock implementation for testing
        require_relative '../../../spec/support/langchain_mock'
      else
        require "langchain"
      end
      
      Langchain::LLM::OpenAI.new(api_key: ENV.fetch("OPENAI_API_KEY"))
    end
  end
end
