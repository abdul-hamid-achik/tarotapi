class LocalLlmService
  def initialize(quota = nil)
    @llm_path = ENV.fetch("LOCAL_LLM_PATH", "/opt/llama.cpp/main")
    @model_path = ENV.fetch("LOCAL_LLM_MODEL", "/opt/llama.cpp/models/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf")
    @quota = quota
  end

  def generate_response(prompt, options = {})
    # Default options
    opts = {
      temperature: 0.7,
      max_tokens: 256,
      top_p: 0.95,
      context_window: 512,
      system_prompt: "You are a helpful tarot reading assistant."
    }.merge(options)

    # Track LLM usage if quota provided
    if @quota
      if @quota.llm_calls_exceeded?
        Rails.logger.warn("LLM call quota exceeded for user ##{@quota.user_id}")
        return { error: "llm_quota_exceeded", message: "You have exceeded your monthly LLM call limit" }
      end

      @quota.increment_llm_call!
    end

    # Format the prompt for llama.cpp
    formatted_prompt = <<~PROMPT
      <|im_start|>system
      #{opts[:system_prompt]}
      <|im_end|>
      <|im_start|>user
      #{prompt}
      <|im_end|>
      <|im_start|>assistant
    PROMPT

    # Execute llama.cpp
    start_time = Time.now
    result = execute_llm(formatted_prompt, opts)
    end_time = Time.now

    # Log metrics
    duration = end_time - start_time
    Rails.logger.info("LLM request completed in #{duration.round(2)}s")

    if result[:success]
      {
        content: result[:output].strip,
        model: "local-tinyllama-1.1b",
        tokens: estimate_token_count(prompt, result[:output])
      }
    else
      Rails.logger.error("LLM error: #{result[:error]}")
      { error: "llm_error", message: result[:error] }
    end
  end

  private

  def execute_llm(prompt, opts)
    begin
      command = [
        @llm_path,
        "-m", @model_path,
        "--temp", opts[:temperature].to_s,
        "--top-p", opts[:top_p].to_s,
        "-n", opts[:max_tokens].to_s,
        "-c", opts[:context_window].to_s,
        "--repeat_penalty", "1.1",
        "-p", prompt
      ]

      # Execute command
      output = IO.popen(command, "r", err: [ :child, :out ]) { |io| io.read }

      # Check for errors in output
      if output.include?("error") || output.include?("Error") || output.include?("failed")
        { success: false, error: output.lines.first(3).join(" ").strip }
      else
        # Extract only the assistant's response
        response = output.gsub(prompt, "")

        # Remove any trailing tokens or unfinished sequences
        response = response.gsub(/<\|im_start\|>.*$/m, "")
          .gsub(/<\|im_end\|>.*$/m, "")

        { success: true, output: response }
      end
    rescue => e
      { success: false, error: e.message }
    end
  end

  def estimate_token_count(prompt, response)
    # Rough estimation: ~1.3 tokens per word
    prompt_tokens = (prompt.split.size * 1.3).round
    response_tokens = (response.split.size * 1.3).round

    { prompt: prompt_tokens, completion: response_tokens, total: prompt_tokens + response_tokens }
  end
end
