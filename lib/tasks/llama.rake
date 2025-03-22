namespace :llama do
  desc "Install llama.cpp for Ruby gem (optimized for ARM)"
  task :install do
    llama_dir = ENV["LLAMA_CPP_DIR"] || File.join(Dir.home, ".llama_cpp")
    puts Rainbow("Installing llama.cpp to #{llama_dir} with ARM optimizations").bright.green

    # Create directory and remove existing installation if present
    FileUtils.mkdir_p(llama_dir)
    sh "rm -rf #{llama_dir}/*" if Dir.exist?(llama_dir) && !Dir.empty?(llama_dir)

    # Clone repository (shallow clone for speed)
    sh "git clone --depth=1 https://github.com/ggml-org/llama.cpp.git #{llama_dir}"

    # Build with ARM-optimized options
    Dir.chdir(llama_dir) do
      sh "mkdir -p build"
      Dir.chdir("build") do
        cmake_options = [
          "-DBUILD_SHARED_LIBS=ON",       # Build as shared library for gem
          "-DLLAMA_NATIVE=OFF",           # Don't optimize for current CPU
          "-DLLAMA_F16C=OFF",             # Disable x86 specific instructions
          "-DLLAMA_FMA=OFF",              # Disable x86 specific instructions
          "-DLLAMA_AVX=OFF",              # Disable x86 specific instructions
          "-DLLAMA_AVX2=OFF",             # Disable x86 specific instructions
          "-DLLAMA_AVX512=OFF",           # Disable x86 specific instructions
          "-DLLAMA_NO_ACCELERATE=ON",     # Disable macOS Accelerate framework
          "-DCMAKE_C_FLAGS='-O3'",        # Basic optimization
          "-DCMAKE_CXX_FLAGS='-O3'"       # Basic optimization
        ]

        puts "Configuring ARM-optimized build..."
        sh "cmake #{cmake_options.join(' ')} .."
        sh "CMAKE_BUILD_PARALLEL_LEVEL=#{ENV['JOBS'] || 4} cmake --build . --config Release --target llama"

        # Try fallback build if the first attempt fails
        unless File.exist?("bin/main") || File.exist?("libllama.so") || File.exist?("libllama.dylib")
          puts Rainbow("Primary build failed, trying fallback build configuration...").yellow
          FileUtils.rm_rf("*")  # Clean build directory

          fallback_options = [
            "-DBUILD_SHARED_LIBS=ON",
            "-DLLAMA_NATIVE=OFF",
            "-DLLAMA_METAL=OFF",          # Disable Metal framework
            "-DCMAKE_C_FLAGS='-O2'",      # Less aggressive optimization
            "-DCMAKE_CXX_FLAGS='-O2'"     # Less aggressive optimization
          ]

          sh "cmake #{fallback_options.join(' ')} .."
          sh "CMAKE_BUILD_PARALLEL_LEVEL=#{ENV['JOBS'] || 4} cmake --build . --config Release --target llama"
        end
      end
    end

    # Set environment variables
    puts "\nTo use llama.cpp, set these environment variables:"
    puts "export LLAMA_CPP_DIR=#{llama_dir}"
    puts "export LIBRARY_PATH=#{llama_dir}/build"
    puts "export LD_LIBRARY_PATH=#{llama_dir}/build"
    puts "export CPATH=#{llama_dir}"
    puts "\nAdd these to your ~/.bashrc or ~/.zshrc to make them permanent"
  end

  desc "Download a small model for testing"
  task :download_model do
    model_dir = ENV["LLAMA_MODEL_DIR"] || File.join(Dir.home, ".llama_models")
    model_path = File.join(model_dir, "tinyllama-1.1b-chat-v1.0.Q4_0.gguf")

    # Create directory if it doesn't exist
    sh "mkdir -p #{model_dir}"

    # Only download if the model doesn't exist
    unless File.exist?(model_path)
      puts "Downloading small model for testing to #{model_path}"
      model_url = "https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q4_0.gguf"
      sh "curl -L #{model_url} -o #{model_path}"
    else
      puts "Model already exists at #{model_path}"
    end

    puts "Model path: #{model_path}"
  end

  desc "Set up llama.cpp and download a test model"
  task setup: [ :install, :download_model ]

  desc "Install the llama_cpp gem with the correct environment variables"
  task :install_gem do
    llama_dir = ENV["LLAMA_CPP_DIR"] || File.join(Dir.home, ".llama_cpp")

    # Set environment variables for the bundle command
    env_vars = {
      "LLAMA_CPP_DIR" => llama_dir,
      "LIBRARY_PATH" => "#{llama_dir}/build",
      "LD_LIBRARY_PATH" => "#{llama_dir}/build",
      "CPATH" => llama_dir
    }

    # Run bundle command with the environment variables
    env_string = env_vars.map { |k, v| "#{k}=#{v}" }.join(" ")
    sh "#{env_string} bundle add llama_cpp"
  end

  desc "Test the llama_cpp gem with a simple query"
  task :test do
    model_dir = ENV["LLAMA_MODEL_DIR"] || File.join(Dir.home, ".llama_models")
    model_path = File.join(model_dir, "tinyllama-1.1b-chat-v1.0.Q4_0.gguf")

    puts "Testing llama_cpp gem..."

    # Create a simple Ruby script to test the gem
    test_script = <<-RUBY
    require 'llama_cpp'

    puts "Loading llama_cpp backend..."
    backend = LLamaCpp::Backend.default

    puts "Loading model from #{model_path}..."
    model_params = LLamaCpp::ModelParams.new
    model = LLamaCpp::Model.new(backend, "#{model_path}", model_params)

    puts "Creating context..."
    context_params = LLamaCpp::ContextParams.new
    context_params.n_ctx = 512
    context = model.new_context(context_params)

    puts "Generating response to prompt..."
    prompt = "What is the capital of France?"
    puts "Prompt: \#{prompt}"

    tokens = context.tokenize(prompt.bytes, true)
    context.eval(tokens)

    generated_text = ""
    n_predict = 100
    n_predict.times do |i|
      token = context.generate
      break if token == context.token_eos
      text = context.detokenize([token]).pack('C*')
      print text
      generated_text += text
    end

    puts "\nGeneration complete!"
    RUBY

    # Write the test script to a temporary file
    require "tempfile"
    file = Tempfile.new([ "llama_test", ".rb" ])
    file.write(test_script)
    file.close

    # Execute the test script with the required environment variables
    llama_dir = ENV["LLAMA_CPP_DIR"] || File.join(Dir.home, ".llama_cpp")
    env_vars = {
      "LLAMA_CPP_DIR" => llama_dir,
      "LIBRARY_PATH" => "#{llama_dir}/build",
      "LD_LIBRARY_PATH" => "#{llama_dir}/build",
      "CPATH" => llama_dir
    }

    env_string = env_vars.map { |k, v| "#{k}=#{v}" }.join(" ")
    sh "#{env_string} ruby #{file.path}"

    # Remove the temporary file
    file.unlink
  end

  desc "Run a Docker container with llama.cpp pre-built"
  task :docker do
    puts Rainbow("Running a container with ARM-optimized llama.cpp").bright.green
    cmd = "docker run --rm -it -v #{Dir.pwd}:/app -w /app tarot_api:latest bash"
    puts "Executing: #{cmd}"
    exec cmd
  end

  desc "Create a Docker container for CI with ARM-optimized llama.cpp"
  task :create_ci_dockerfile do
    dockerfile = <<-DOCKERFILE
FROM ruby:3.4-slim-bookworm

# Install build dependencies
RUN apt-get update && apt-get install -y \\
    build-essential \\
    git \\
    cmake \\
    wget \\
    libpq-dev \\
    pkg-config \\
    libyaml-dev \\
    curl \\
    && apt-get clean

# Build llama.cpp with ARM optimizations
RUN git clone --depth=1 https://github.com/ggml-org/llama.cpp.git /opt/llama.cpp && \\
    cd /opt/llama.cpp && \\
    mkdir -p build && \\
    cd build && \\
    cmake \\
      -DLLAMA_NATIVE=OFF \\
      -DLLAMA_F16C=OFF \\
      -DLLAMA_FMA=OFF \\
      -DLLAMA_AVX=OFF \\
      -DLLAMA_AVX2=OFF \\
      -DLLAMA_AVX512=OFF \\
      -DLLAMA_NO_ACCELERATE=ON \\
      -DBUILD_SHARED_LIBS=ON \\
      -DCMAKE_C_FLAGS="-O3" \\
      -DCMAKE_CXX_FLAGS="-O3" \\
      .. && \\
    CMAKE_BUILD_PARALLEL_LEVEL=4 cmake --build . --config Release && \\
    mkdir -p /opt/llama.cpp/models

# Setup environment variables for llama_cpp gem
ENV LLAMA_CPP_DIR=/opt/llama.cpp
ENV LIBRARY_PATH=/opt/llama.cpp/build
ENV LD_LIBRARY_PATH=/opt/llama.cpp/build
ENV CPATH=/opt/llama.cpp
ENV LOCAL_LLM_PATH=/opt/llama.cpp/build/bin/main

# Install bundler
RUN gem install bundler

# Create a directory for the application
WORKDIR /app

# Copy Gemfile and install dependencies
COPY Gemfile Gemfile.lock ./
RUN bundle install

# Copy the application
COPY . .

# Run the tests
CMD ["bundle", "exec", "rake", "test"]
DOCKERFILE

    File.write("Dockerfile.llama_ci", dockerfile)
    puts Rainbow("Created Dockerfile.llama_ci with ARM optimizations").bright.green
    puts "Build with: docker build -f Dockerfile.llama_ci -t tarot-api-ci ."
  end

  desc "Help: Show all available commands"
  task :help do
    puts "Available llama tasks:"
    puts "  rake llama:install         # Install llama.cpp for Ruby gem (optimized for ARM)"
    puts "  rake llama:download_model  # Download a small model for testing"
    puts "  rake llama:setup           # Set up llama.cpp and download a test model"
    puts "  rake llama:install_gem     # Install the llama_cpp gem with correct environment"
    puts "  rake llama:test            # Test the llama_cpp gem with a simple query"
    puts "  rake llama:docker          # Run a Docker container with llama.cpp pre-built"
    puts "  rake llama:create_ci_dockerfile # Create a Dockerfile for CI with llama.cpp"
    puts "  rake llama:help            # Show this help message"
    puts "\nEnvironment variables:"
    puts "  LLAMA_CPP_DIR              # Directory for llama.cpp installation (default: ~/.llama_cpp)"
    puts "  LLAMA_MODEL_DIR            # Directory for model storage (default: ~/.llama_models)"
    puts "  JOBS                       # Number of jobs for parallel build (default: 4)"
  end
end
