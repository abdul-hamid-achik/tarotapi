module LlmProviders
  class OpenaiProvider < BaseProvider
    def initialize(quota = nil)
      super(quota)
      @client = OpenAI::Client.new(
        access_token: ENV.fetch("OPENAI_API_KEY"),
        request_timeout: 60
      )
    end

    def generate_response(prompt, options = {})
      # Default options
      opts = {
        temperature: 0.7,
        max_tokens: 500,
        system_prompt: "You are a helpful tarot reading assistant.",
        model: ENV.fetch("DEFAULT_LLM_MODEL", "gpt-4o-mini")
      }.merge(options)

      return format_error("llm_quota_exceeded", "You have exceeded your monthly LLM call limit") unless track_usage

      # Format messages for GPT
      messages = [
        { role: "system", content: opts[:system_prompt] },
        { role: "user", content: prompt }
      ]

      start_time = Time.now

      begin
        response = @client.chat(
          parameters: {
            model: opts[:model],
            messages: messages,
            temperature: opts[:temperature],
            max_tokens: opts[:max_tokens]
          }
        )

        duration = Time.now - start_time
        Rails.logger.info("OpenAI LLM request completed in #{duration.round(2)}s")

        if response["error"]
          Rails.logger.error("OpenAI LLM error: #{response["error"]["message"]}")
          format_error("llm_error", response["error"]["message"])
        else
          format_response(
            response["choices"][0]["message"]["content"].strip,
            opts[:model],
            {
              prompt: response["usage"]["prompt_tokens"],
              completion: response["usage"]["completion_tokens"],
              total: response["usage"]["total_tokens"]
            }
          )
        end
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
        model: ENV.fetch("DEFAULT_LLM_MODEL", "gpt-4o-mini")
      }.merge(options)

      return format_error("llm_quota_exceeded", "You have exceeded your monthly LLM call limit") unless track_usage

      # Format messages for GPT
      messages = [
        { role: "system", content: opts[:system_prompt] },
        { role: "user", content: prompt }
      ]

      begin
        full_response = ""

        @client.chat(
          parameters: {
            model: opts[:model],
            messages: messages,
            temperature: opts[:temperature],
            max_tokens: opts[:max_tokens],
            stream: true
          }
        ) do |chunk, _bytesize|
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
      [ "gpt-4o-mini", "gpt-4-turbo", "gpt-3.5-turbo" ]
    end
  end
end
