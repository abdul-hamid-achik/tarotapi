require 'rails_helper'

RSpec.describe LlmService do
  # Use let! to eagerly load the instance
  let!(:service) { LlmService.instance }

  # Mock objects
  let(:user) { instance_double(User) }
  let(:reading_quota) { instance_double(ReadingQuota) }
  let(:subscription_plan) { instance_double(SubscriptionPlan) }
  let(:provider) { instance_double('LlmProvider') }

  describe '#set_user' do
    before do
      allow(user).to receive(:reading_quota).and_return(reading_quota)
      allow(service).to receive(:determine_tier).with(user).and_return(:premium)
    end

    it 'sets the user context' do
      service.set_user(user)

      expect(service.instance_variable_get(:@user)).to eq(user)
      expect(service.instance_variable_get(:@quota)).to eq(reading_quota)
      expect(service.instance_variable_get(:@tier)).to eq(:premium)
    end

    it 'handles nil user' do
      service.set_user(nil)

      expect(service.instance_variable_get(:@user)).to be_nil
      expect(service.instance_variable_get(:@quota)).to be_nil
      expect(service.instance_variable_get(:@tier)).to be_nil
    end
  end

  describe '#generate_response' do
    let(:prompt) { "Tell me about the Fool card" }
    let(:options) { { temperature: 0.7 } }
    let(:expected_response) { { content: "The Fool represents new beginnings..." } }

    context 'when user has quota available' do
      before do
        service.instance_variable_set(:@tier, :premium)
        service.instance_variable_set(:@quota, reading_quota)

        allow(reading_quota).to receive(:llm_calls_this_month).and_return(5)
        allow(reading_quota).to receive(:llm_calls_limit).and_return(100)
        allow(reading_quota).to receive(:increment_llm_call!).with(2)

        allow(LlmProviderFactory).to receive(:get_provider_for_model)
          .with("claude-3-5-sonnet-v2@20241022", reading_quota)
          .and_return(provider)

        allow(provider).to receive(:generate_response)
          .with(prompt, hash_including(options).merge(model: "claude-3-5-sonnet-v2@20241022"))
          .and_return(expected_response)
      end

      it 'generates a response using the provider' do
        response = service.generate_response(prompt, options)

        expect(response).to eq(expected_response)
        expect(reading_quota).to have_received(:increment_llm_call!).with(2) # premium multiplier
      end

      it 'uses the specified model if provided' do
        custom_model = "gpt-4o-mini"
        allow(LlmProviderFactory).to receive(:get_provider_for_model)
          .with(custom_model, reading_quota)
          .and_return(provider)

        allow(provider).to receive(:generate_response)
          .with(prompt, hash_including(options).merge(model: custom_model))
          .and_return(expected_response)

        response = service.generate_response(prompt, options.merge(model: custom_model))

        expect(response).to eq(expected_response)
      end
    end

    context 'when user has exceeded quota' do
      before do
        service.instance_variable_set(:@tier, :premium)
        service.instance_variable_set(:@quota, reading_quota)

        allow(reading_quota).to receive(:llm_calls_this_month).and_return(99)
        allow(reading_quota).to receive(:llm_calls_limit).and_return(100)
      end

      it 'returns quota exceeded error' do
        response = service.generate_response(prompt, options)

        expect(response).to eq({
          error: "llm_quota_exceeded",
          message: "You have exceeded your monthly LLM call limit"
        })
      end
    end

    context 'when no user is set' do
      before do
        service.instance_variable_set(:@tier, nil)
        service.instance_variable_set(:@quota, nil)

        allow(LlmProviderFactory).to receive(:get_provider_for_model)
          .with("llama3:8b", nil)
          .and_return(provider)

        allow(provider).to receive(:generate_response)
          .with(prompt, hash_including(options).merge(model: "llama3:8b"))
          .and_return(expected_response)
      end

      it 'defaults to free tier' do
        response = service.generate_response(prompt, options)

        expect(response).to eq(expected_response)
      end
    end
  end

  describe '#generate_streaming_response' do
    let(:prompt) { "Tell me about the Fool card" }
    let(:options) { { temperature: 0.7 } }
    let(:chunks) { [ "The", " Fool", " represents", " new", " beginnings..." ] }
    let(:block) { proc { |chunk| } }

    context 'when user has quota available' do
      before do
        service.instance_variable_set(:@tier, :premium)
        service.instance_variable_set(:@quota, reading_quota)

        allow(reading_quota).to receive(:llm_calls_this_month).and_return(5)
        allow(reading_quota).to receive(:llm_calls_limit).and_return(100)
        allow(reading_quota).to receive(:increment_llm_call!).with(2)

        allow(LlmProviderFactory).to receive(:get_provider_for_model)
          .with("claude-3-5-sonnet-v2@20241022", reading_quota)
          .and_return(provider)
      end

      it 'streams the response through provider' do
        expect(provider).to receive(:generate_streaming_response)
          .with(prompt, hash_including(options).merge(model: "claude-3-5-sonnet-v2@20241022"), &block)

        service.generate_streaming_response(prompt, options, &block)
        expect(reading_quota).to have_received(:increment_llm_call!).with(2)
      end
    end
  end

  describe '#available_models' do
    let(:ollama_provider) { instance_double('OllamaProvider') }

    before do
      allow(LlmProviderFactory).to receive(:get_provider).with(:ollama).and_return(ollama_provider)
      allow(ollama_provider).to receive(:available_models).and_return([ "llama3:8b", "mistral" ])
    end

    it 'returns models based on free tier' do
      models = service.available_models(:free)
      expect(models).to eq([ "llama3:8b", "mistral" ])
    end

    it 'returns models based on premium tier' do
      models = service.available_models(:premium)
      expect(models).to eq([ "gpt-4o-mini", "claude-3-5-sonnet-v2@20241022" ])
    end

    it 'returns models based on professional tier' do
      models = service.available_models(:professional)
      expect(models).to include("gpt-4o-mini", "claude-3-5-sonnet-v2@20241022", "claude-3-7-sonnet@20250219", "llama3:8b", "mistral")
      expect(models.length).to eq(5)
    end

    it 'defaults to current tier if set' do
      service.instance_variable_set(:@tier, :premium)
      models = service.available_models
      expect(models).to eq([ "gpt-4o-mini", "claude-3-5-sonnet-v2@20241022" ])
    end

    it 'defaults to free tier if no tier specified or set' do
      service.instance_variable_set(:@tier, nil)
      models = service.available_models
      expect(models).to eq([ "llama3:8b", "mistral" ])
    end
  end

  describe '#determine_tier' do
    context 'when user is nil' do
      it 'returns free tier' do
        tier = service.send(:determine_tier, nil)
        expect(tier).to eq(:free)
      end
    end

    context 'when user has a subscription plan' do
      before do
        allow(user).to receive(:subscription_plan).and_return(subscription_plan)
        allow(user).to receive(:subscription_status).and_return('active')
      end

      it 'returns professional tier for unlimited plan' do
        allow(subscription_plan).to receive(:name).and_return('unlimited')
        tier = service.send(:determine_tier, user)
        expect(tier).to eq(:professional)
      end

      it 'returns premium tier for premium plan' do
        allow(subscription_plan).to receive(:name).and_return('premium')
        tier = service.send(:determine_tier, user)
        expect(tier).to eq(:premium)
      end

      it 'returns free tier for basic plan' do
        allow(subscription_plan).to receive(:name).and_return('basic')
        tier = service.send(:determine_tier, user)
        expect(tier).to eq(:free)
      end
    end

    context 'when user has no subscription plan' do
      before do
        allow(user).to receive(:subscription_plan).and_return(nil)
        allow(user).to receive(:subscription_status).and_return('inactive')
      end

      it 'returns free tier' do
        tier = service.send(:determine_tier, user)
        expect(tier).to eq(:free)
      end
    end
  end
end
