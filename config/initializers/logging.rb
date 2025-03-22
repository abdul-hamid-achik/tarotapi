# Configure structured logging for the application
require 'semantic_logger'
require 'lograge'

Rails.application.configure do
  # Configure Lograge
  config.lograge.enabled = true
  config.lograge.formatter = Lograge::Formatters::Json.new
  config.lograge.custom_options = lambda do |event|
    exceptions = %w[controller action format id]
    {
      time: Time.now.iso8601,
      host: Socket.gethostname,
      pid: Process.pid,
      environment: Rails.env,
      request_id: event.payload[:request_id],
      params: event.payload[:params].except(*exceptions),
      custom_payload: event.payload[:custom_payload]
    }
  end

  # Specific additional fields for API requests
  config.lograge.custom_payload do |controller|
    {
      user_id: controller.try(:current_user)&.id,
      remote_ip: controller.request.remote_ip,
      user_agent: controller.request.user_agent
    }
  end

  # Configure Semantic Logger
  SemanticLogger.application = Rails.application.class.module_parent_name
  SemanticLogger.add_appender(io: $stdout, formatter: :json)
  
  # Set default log level based on environment
  config.log_level = case Rails.env
                     when 'production'
                       ENV.fetch('LOG_LEVEL', 'info').to_sym
                     when 'staging'
                       ENV.fetch('LOG_LEVEL', 'info').to_sym
                     else
                       ENV.fetch('LOG_LEVEL', 'debug').to_sym
                     end
  
  # Keep standard Rails logs for development to maintain familiar output
  if Rails.env.development?
    SemanticLogger.add_appender(file_name: "#{Rails.root}/log/#{Rails.env}.log", formatter: :color)
  end
end 