class LlmProviderFactory
  # Provider types
  PROVIDER_TYPES = {
    ollama: "LlmProviders::OllamaProvider",
    openai: "LlmProviders::OpenaiProvider",
    anthropic: "LlmProviders::AnthropicProvider"
  }.freeze

  # Model to provider mapping
  MODEL_PROVIDERS = {
    # Ollama models (any model with these prefixes)
    "llama3" => :ollama,
    "mistral" => :ollama,
    "gemma" => :ollama,
    "phi" => :ollama,
    "yi:" => :ollama,
    "qwen:" => :ollama,

    # OpenAI models
    "gpt-3.5" => :openai,
    "gpt-4" => :openai,

    # Anthropic models
    "claude-" => :anthropic,
    "claude-3" => :anthropic,
    "claude-instant" => :anthropic
  }.freeze

  class << self
    # Get provider by type
    def get_provider(type, quota = nil)
      provider_class = PROVIDER_TYPES[type.to_sym]
      return nil unless provider_class

      provider_class.constantize.new(quota)
    end

    # Get provider for model
    def get_provider_for_model(model, quota = nil)
      # Find provider type for this model
      provider_key = MODEL_PROVIDERS.keys.find { |key| model.to_s.start_with?(key) }
      provider_type = provider_key ? MODEL_PROVIDERS[provider_key] : :openai

      get_provider(provider_type, quota)
    end

    # Get local provider (Ollama)
    def get_local_provider(quota = nil)
      get_provider(:ollama, quota)
    end

    # Get all supported providers
    def get_all_providers(quota = nil)
      PROVIDER_TYPES.keys.map do |type|
        [ type, get_provider(type, quota) ]
      end.to_h
    end
  end
end
