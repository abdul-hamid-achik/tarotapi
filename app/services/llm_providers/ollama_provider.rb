module LlmProviders
  class OllamaProvider < BaseProvider
    def initialize(quota = nil)
      super(quota)
      @client = initialize_client
    end

    def generate_response(prompt, options = {})
      # Default options
      opts = {
        temperature: 0.7,
        max_tokens: 256,
        system_prompt: "You are a helpful tarot reading assistant.",
        model: ENV.fetch("OLLAMA_MODEL", "llama3:8b")
      }.merge(options)
      
      return format_error("llm_quota_exceeded", "You have exceeded your monthly LLM call limit") unless track_usage

      start_time = Time.now

      begin
        # Format messages for Ollama
        messages = [
          { role: "system", content: opts[:system_prompt] },
          { role: "user", content: prompt }
        ]

        # Send request to Ollama
        response = @client.complete(
          prompt: format_messages_for_ollama(messages),
          model: opts[:model],
          options: {
            temperature: opts[:temperature],
            num_predict: opts[:max_tokens]
          }
        )

        duration = Time.now - start_time
        Rails.logger.info("Ollama LLM request completed in #{duration.round(2)}s")

        # Parse response
        format_response(
          response.dig("response") || response.to_s,
          opts[:model],
          {
            prompt: response.dig("prompt_eval_count") || 0,
            completion: response.dig("eval_count") || 0,
            total: (response.dig("prompt_eval_count") || 0) + (response.dig("eval_count") || 0)
          }
        )
      rescue => e
        Rails.logger.error("Ollama LLM error: #{e.message}")
        format_error("llm_error", e.message)
      end
    end

    def generate_streaming_response(prompt, options = {}, &block)
      # Default options
      opts = {
        temperature: 0.7,
        max_tokens: 256,
        system_prompt: "You are a helpful tarot reading assistant.",
        model: ENV.fetch("OLLAMA_MODEL", "llama3:8b")
      }.merge(options)
      
      return format_error("llm_quota_exceeded", "You have exceeded your monthly LLM call limit") unless track_usage

      begin
        # Format messages for Ollama
        messages = [
          { role: "system", content: opts[:system_prompt] },
          { role: "user", content: prompt }
        ]

        # Stream response from Ollama
        response_text = ""
        
        @client.stream(
          prompt: format_messages_for_ollama(messages),
          model: opts[:model],
          options: {
            temperature: opts[:temperature],
            num_predict: opts[:max_tokens]
          }
        ) do |chunk|
          content = chunk.dig("response")
          if content
            response_text += content
            yield content if block_given?
          end
        end

        format_response(response_text, opts[:model])
      rescue => e
        Rails.logger.error("Ollama streaming LLM error: #{e.message}")
        format_error("llm_error", e.message)
      end
    end

    def available_models
      begin
        response = @client.models
        response.dig("models")&.map { |model| model["name"] } || ["llama3:8b"]
      rescue => e
        Rails.logger.error("Failed to fetch Ollama models: #{e.message}")
        ["llama3:8b"]
      end
    end

    private

    def initialize_client
      require "langchain"
      api_host = ENV.fetch("OLLAMA_API_HOST", "http://ollama:11434")
      Langchain::LLM::Ollama.new(url: api_host)
    end

    def format_messages_for_ollama(messages)
      # Extract system message
      system_message = messages.find { |m| m[:role] == "system" }
      user_messages = messages.select { |m| m[:role] == "user" }
      
      # Format for Ollama
      prompt = ""
      prompt += "<|system|>\n#{system_message[:content]}\n" if system_message
      
      # Add user messages
      user_messages.each do |msg|
        prompt += "<|user|>\n#{msg[:content]}\n<|assistant|>\n"
      end
      
      prompt
    end
  end
end 