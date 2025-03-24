class OllamaService
  include Loggable

  OLLAMA_URL = ENV.fetch("OLLAMA_URL", "http://localhost:11434")

  def self.available_models
    begin
      response = Faraday.get("#{OLLAMA_URL}/api/tags")
      return [] unless response.success?

      models = JSON.parse(response.body)["models"]
      models.map { |model| model["name"] }
    rescue => e
      log_error("Failed to fetch Ollama models", { error: e.message, url: OLLAMA_URL })
      []
    end
  end

  def self.list_models
    available_models
  end

  def self.generate(prompt, model: "llama2", options: {})
    url = "#{OLLAMA_URL}/api/generate"

    # Log request details for observability
    log_info("Sending request to Ollama", {
      model: model,
      prompt_length: prompt.length,
      options: options.except(:api_key)
    })

    start_time = Time.now

    payload = {
      model: model,
      prompt: prompt,
      options: options
    }

    begin
      response = Faraday.post(url) do |req|
        req.headers["Content-Type"] = "application/json"
        req.body = payload.to_json
      end

      duration = Time.now - start_time

      if response.success?
        parsed = JSON.parse(response.body)

        # Log successful completion with metrics
        log_info("Ollama request completed", {
          model: model,
          duration_seconds: duration.round(2),
          response_length: parsed["response"].length,
          total_duration: parsed["total_duration"]
        })

        parsed
      else
        # Log error response
        log_error("Ollama API error", {
          model: model,
          status: response.status,
          body: response.body,
          duration_seconds: duration.round(2)
        })

        { error: "API Error: #{response.status}", status: response.status }
      end
    rescue => e
      duration = Time.now - start_time

      # Log connection/parsing errors with detailed context
      log_error("Ollama error", {
        model: model,
        error: e.message,
        error_class: e.class.name,
        duration_seconds: duration.round(2),
        backtrace: e.backtrace&.first(3)
      })

      { error: e.message }
    end
  end

  def self.pull_model(model_name)
    url = URI.parse("#{OLLAMA_URL}/api/pull")

    body = { name: model_name }.to_json
    headers = { "Content-Type" => "application/json" }

    begin
      http = Net::HTTP.new(url.host, url.port)
      request = Net::HTTP::Post.new(url.path, headers)
      request.body = body

      response = http.request(request)

      if response.is_a?(Net::HTTPSuccess)
        { success: true, message: "Model #{model_name} pulled successfully" }
      else
        { success: false, message: "Failed to pull model: #{response.body}" }
      end
    rescue => e
      { success: false, message: "Error pulling model: #{e.message}" }
    end
  end

  def self.check_status
    url = URI.parse("#{OLLAMA_URL}/api/version")

    begin
      response = Net::HTTP.get_response(url)
      response.is_a?(Net::HTTPSuccess)
    rescue
      false
    end
  end
end
