require 'rails_helper'

RSpec.describe OllamaService do
  describe '.available_models' do
    let(:models_response) do
      {
        "models" => [
          { "name" => "llama3:8b" },
          { "name" => "mistral" },
          { "name" => "phi3" }
        ]
      }.to_json
    end

    let(:empty_models_response) do
      { "models" => [] }.to_json
    end

    let(:base_url) { "http://localhost:11434" }
    let(:tags_url) { URI.parse("#{base_url}/api/tags") }

    before do
      allow(OllamaService).to receive(:base_url).and_return(base_url)
    end

    context 'when the API request is successful' do
      it 'returns a list of model names' do
        mock_response = instance_double(Net::HTTPSuccess, body: models_response)
        allow(Net::HTTP).to receive(:get_response).with(tags_url).and_return(mock_response)
        allow(mock_response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)

        result = OllamaService.available_models
        expect(result).to eq([ "llama3:8b", "mistral", "phi3" ])
      end

      it 'returns an empty array when no models are available' do
        mock_response = instance_double(Net::HTTPSuccess, body: empty_models_response)
        allow(Net::HTTP).to receive(:get_response).with(tags_url).and_return(mock_response)
        allow(mock_response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)

        result = OllamaService.available_models
        expect(result).to eq([])
      end
    end

    context 'when the API request fails' do
      it 'returns an empty array when response is not successful' do
        mock_response = instance_double(Net::HTTPBadRequest, body: '')
        allow(Net::HTTP).to receive(:get_response).with(tags_url).and_return(mock_response)
        allow(mock_response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(false)

        result = OllamaService.available_models
        expect(result).to eq([])
      end

      it 'logs an error and returns an empty array when an exception occurs' do
        allow(Net::HTTP).to receive(:get_response).with(tags_url).and_raise(StandardError.new("Connection refused"))
        allow(Rails.logger).to receive(:error)

        result = OllamaService.available_models
        expect(result).to eq([])
        expect(Rails.logger).to have_received(:error).with("Failed to fetch Ollama models: Connection refused")
      end
    end
  end

  describe '.pull_model' do
    let(:model_name) { "llama3:8b" }
    let(:base_url) { "http://localhost:11434" }
    let(:pull_url) { URI.parse("#{base_url}/api/pull") }

    before do
      allow(OllamaService).to receive(:base_url).and_return(base_url)
    end

    context 'when the API request is successful' do
      it 'returns success message' do
        mock_http = instance_double(Net::HTTP)
        mock_request = instance_double(Net::HTTP::Post)
        mock_response = instance_double(Net::HTTPSuccess)

        allow(Net::HTTP).to receive(:new).with(pull_url.host, pull_url.port).and_return(mock_http)
        allow(Net::HTTP::Post).to receive(:new).with(pull_url.path, { "Content-Type" => "application/json" }).and_return(mock_request)
        allow(mock_request).to receive(:body=)
        allow(mock_http).to receive(:request).with(mock_request).and_return(mock_response)
        allow(mock_response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)

        result = OllamaService.pull_model(model_name)
        expect(result).to eq({ success: true, message: "Model #{model_name} pulled successfully" })
        expect(mock_request).to have_received(:body=).with({ name: model_name }.to_json)
      end
    end

    context 'when the API request fails' do
      it 'returns failure message when response is not successful' do
        mock_http = instance_double(Net::HTTP)
        mock_request = instance_double(Net::HTTP::Post)
        mock_response = instance_double(Net::HTTPBadRequest, body: '{"error": "Model not found"}')

        allow(Net::HTTP).to receive(:new).with(pull_url.host, pull_url.port).and_return(mock_http)
        allow(Net::HTTP::Post).to receive(:new).with(pull_url.path, { "Content-Type" => "application/json" }).and_return(mock_request)
        allow(mock_request).to receive(:body=)
        allow(mock_http).to receive(:request).with(mock_request).and_return(mock_response)
        allow(mock_response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(false)

        result = OllamaService.pull_model(model_name)
        expect(result).to eq({ success: false, message: "Failed to pull model: {\"error\": \"Model not found\"}" })
      end

      it 'returns error message when an exception occurs' do
        mock_http = instance_double(Net::HTTP)
        mock_request = instance_double(Net::HTTP::Post)

        allow(Net::HTTP).to receive(:new).with(pull_url.host, pull_url.port).and_return(mock_http)
        allow(Net::HTTP::Post).to receive(:new).with(pull_url.path, { "Content-Type" => "application/json" }).and_return(mock_request)
        allow(mock_request).to receive(:body=)
        allow(mock_http).to receive(:request).with(mock_request).and_raise(StandardError.new("Connection refused"))

        result = OllamaService.pull_model(model_name)
        expect(result).to eq({ success: false, message: "Error pulling model: Connection refused" })
      end
    end
  end
end
