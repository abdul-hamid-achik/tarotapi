module LlmProviders
  class BaseProvider
    attr_reader :quota

    def initialize(quota = nil)
      @quota = quota
    end

    def generate_response(prompt, options = {})
      raise NotImplementedError, "Subclasses must implement #generate_response"
    end

    def generate_streaming_response(prompt, options = {}, &block)
      raise NotImplementedError, "Subclasses must implement #generate_streaming_response"
    end

    def available_models
      raise NotImplementedError, "Subclasses must implement #available_models"
    end

    protected

    def track_usage(multiplier = 1)
      return true unless @quota

      if @quota.llm_calls_exceeded?
        Rails.logger.warn("LLM call quota exceeded for user ##{@quota.user_id}")
        return false
      end

      @quota.increment_llm_call!(multiplier)
      true
    end

    def format_response(content, model, usage = nil)
      {
        content: content,
        model: model,
        tokens: usage || {
          prompt: 0,
          completion: 0,
          total: 0
        }
      }
    end

    def format_error(error_code, message)
      {
        error: error_code,
        message: message
      }
    end
  end
end
