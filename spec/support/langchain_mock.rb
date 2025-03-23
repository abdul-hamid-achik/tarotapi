# This file mocks the langchain gem for testing

module Langchain
  module LLM
    class Ollama
      def initialize(url:)
        # Mock initialization
      end

      def complete(prompt:, model:, options: {})
        {
          "response" => "Mocked Ollama response",
          "prompt_eval_count" => 10,
          "eval_count" => 20
        }
      end

      def stream(prompt:, model:, options: {})
        yield({ "response" => "Mocked stream chunk" })
      end

      def models
        {
          "models" => [
            { "name" => "llama3:8b" },
            { "name" => "llama3:70b" }
          ]
        }
      end
    end

    class Anthropic
      def initialize(api_key:)
        # Mock initialization
      end

      def complete(prompt:, model:, max_tokens:, temperature:)
        {
          "content" => [
            { "text" => "Mocked Anthropic response" }
          ]
        }
      end

      def stream(prompt:, model:, max_tokens:, temperature:)
        yield({ "content" => [ { "text" => "Mocked stream chunk" } ] })
      end
    end

    class OpenAI
      def initialize(api_key:)
        # Mock initialization
      end

      def complete(prompt:, model:, max_tokens:, temperature:)
        {
          "choices" => [
            { "message" => { "content" => "Mocked OpenAI response" } }
          ],
          "usage" => {
            "prompt_tokens" => 10,
            "completion_tokens" => 20,
            "total_tokens" => 30
          }
        }
      end

      def stream(prompt:, model:, max_tokens:, temperature:)
        yield({ "choices" => [ { "delta" => { "content" => "Mocked stream chunk" } } ] })
      end
    end
  end
end
