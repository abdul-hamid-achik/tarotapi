require 'rails_helper'

RSpec.describe LlmProviderFactory do
  describe '.get_provider' do
    it 'returns the correct provider class for ollama' do
      provider = LlmProviderFactory.get_provider(:ollama)
      expect(provider).to be_a(LlmProviders::OllamaProvider)
    end

    it 'returns the correct provider class for openai' do
      provider = LlmProviderFactory.get_provider(:openai)
      expect(provider).to be_a(LlmProviders::OpenaiProvider)
    end

    it 'returns the correct provider class for anthropic' do
      provider = LlmProviderFactory.get_provider(:anthropic)
      expect(provider).to be_a(LlmProviders::AnthropicProvider)
    end

    it 'returns nil for an invalid provider type' do
      provider = LlmProviderFactory.get_provider(:invalid)
      expect(provider).to be_nil
    end
  end

  describe '.get_provider_for_model' do
    it 'returns Ollama provider for llama3 models' do
      provider = LlmProviderFactory.get_provider_for_model('llama3:8b')
      expect(provider).to be_a(LlmProviders::OllamaProvider)
    end

    it 'returns OpenAI provider for GPT models' do
      provider = LlmProviderFactory.get_provider_for_model('gpt-4o')
      expect(provider).to be_a(LlmProviders::OpenaiProvider)
    end

    it 'returns Anthropic provider for Claude models' do
      provider = LlmProviderFactory.get_provider_for_model('claude-3-opus')
      expect(provider).to be_a(LlmProviders::AnthropicProvider)
    end

    it 'defaults to OpenAI provider for unknown models' do
      provider = LlmProviderFactory.get_provider_for_model('unknown-model')
      expect(provider).to be_a(LlmProviders::OpenaiProvider)
    end
  end

  describe '.get_local_provider' do
    it 'returns the Ollama provider' do
      provider = LlmProviderFactory.get_local_provider
      expect(provider).to be_a(LlmProviders::OllamaProvider)
    end
  end
end
