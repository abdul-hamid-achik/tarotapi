class OllamaService
  class << self
    def available_models
      url = URI.parse("#{base_url}/api/tags")
      
      begin
        response = Net::HTTP.get_response(url)
        
        if response.is_a?(Net::HTTPSuccess)
          JSON.parse(response.body)["models"].map { |m| m["name"] }
        else
          []
        end
      rescue => e
        Rails.logger.error("Failed to fetch Ollama models: #{e.message}")
        []
      end
    end
    
    def pull_model(model_name)
      url = URI.parse("#{base_url}/api/pull")
      
      body = { name: model_name }.to_json
      headers = { 'Content-Type' => 'application/json' }
      
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
    
    def generate_response(model_name, prompt, options = {})
      url = URI.parse("#{base_url}/api/generate")
      
      # Default options
      opts = {
        temperature: 0.7,
        num_predict: 256,
        stream: false
      }.merge(options)
      
      body = {
        model: model_name,
        prompt: prompt,
        stream: opts[:stream],
        temperature: opts[:temperature],
        num_predict: opts[:num_predict]
      }.to_json
      
      headers = { 'Content-Type' => 'application/json' }
      
      begin
        http = Net::HTTP.new(url.host, url.port)
        request = Net::HTTP::Post.new(url.path, headers)
        request.body = body
        
        response = http.request(request)
        
        if response.is_a?(Net::HTTPSuccess)
          JSON.parse(response.body)
        else
          { error: true, message: "Failed to generate response: #{response.body}" }
        end
      rescue => e
        { error: true, message: "Error generating response: #{e.message}" }
      end
    end
    
    def check_status
      url = URI.parse("#{base_url}/api/version")
      
      begin
        response = Net::HTTP.get_response(url)
        response.is_a?(Net::HTTPSuccess)
      rescue
        false
      end
    end
    
    def base_url
      @base_url ||= ENV.fetch("OLLAMA_API_HOST", "http://localhost:11434").gsub(/\/$/, '')
    end
  end
end 