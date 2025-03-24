require 'spec_helper'

# Mock the Rails logger
module Rails
  def self.logger
    @logger ||= Logger.new(nil)
  end
end

# Mock the module to test
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

RSpec.describe LlmProviders::BaseProvider do
  # Use a double instead of attempting to create a real record
  let(:quota) { double("ReadingQuota", user_id: 1) }
  subject { described_class.new(quota) }

  describe "#initialize" do
    it "sets the quota" do
      expect(subject.quota).to eq(quota)
    end

    it "works without a quota" do
      provider = described_class.new
      expect(provider.quota).to be_nil
    end
  end

  describe "#generate_response" do
    it "raises NotImplementedError" do
      expect { subject.generate_response("test prompt") }.to raise_error(NotImplementedError)
    end
  end

  describe "#generate_streaming_response" do
    it "raises NotImplementedError" do
      expect { subject.generate_streaming_response("test prompt") }.to raise_error(NotImplementedError)
    end
  end

  describe "#available_models" do
    it "raises NotImplementedError" do
      expect { subject.available_models }.to raise_error(NotImplementedError)
    end
  end

  describe "#track_usage" do
    context "when quota is nil" do
      let(:provider) { described_class.new }

      it "returns true" do
        expect(provider.send(:track_usage)).to be true
      end
    end

    context "when quota is present" do
      context "when quota is exceeded" do
        before do
          allow(quota).to receive(:llm_calls_exceeded?).and_return(true)
          allow(Rails.logger).to receive(:warn)
        end

        it "returns false" do
          expect(subject.send(:track_usage)).to be false
        end

        it "logs a warning" do
          subject.send(:track_usage)
          expect(Rails.logger).to have_received(:warn).with("LLM call quota exceeded for user #1")
        end
      end

      context "when quota is not exceeded" do
        before do
          allow(quota).to receive(:llm_calls_exceeded?).and_return(false)
          allow(quota).to receive(:increment_llm_call!)
        end

        it "returns true" do
          expect(subject.send(:track_usage)).to be true
        end

        it "increments the usage" do
          subject.send(:track_usage, 2)
          expect(quota).to have_received(:increment_llm_call!).with(2)
        end
      end
    end
  end

  describe "#format_response" do
    it "formats a response with the given content and model" do
      response = subject.send(:format_response, "Hello", "gpt-4")
      expect(response).to include(
        content: "Hello",
        model: "gpt-4"
      )
      expect(response[:tokens]).to include(
        prompt: 0,
        completion: 0,
        total: 0
      )
    end

    it "includes usage information when provided" do
      usage = { prompt: 10, completion: 20, total: 30 }
      response = subject.send(:format_response, "Hello", "gpt-4", usage)
      expect(response[:tokens]).to eq(usage)
    end
  end

  describe "#format_error" do
    it "formats an error response" do
      error = subject.send(:format_error, "rate_limit_exceeded", "Too many requests")
      expect(error).to eq(
        error: "rate_limit_exceeded",
        message: "Too many requests"
      )
    end
  end
end
