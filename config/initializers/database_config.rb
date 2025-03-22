require "aws-sdk-ssm"

# only run in production or if AWS_USE_SSM is set
if Rails.env.production? || ENV["AWS_USE_SSM"] == "true"
  begin
    ssm_client = Aws::SSM::Client.new(
      region: ENV["AWS_DEFAULT_REGION"] || "mx-central-1"
    )

    app_name = ENV["APP_NAME"] || "tarotapi"
    environment = ENV["RAILS_ENV"] || "production"

    # fetch database password from parameter store
    param_name = "/#{app_name}/#{environment}/db_password"
    response = ssm_client.get_parameter(
      name: param_name,
      with_decryption: true
    )

    db_password = response.parameter.value
    db_host = ENV["DB_HOST"].to_s.strip
    db_host = "postgres" if db_host.empty?
    db_name = ENV["DB_NAME"].to_s.strip
    db_user = ENV["DB_USERNAME"].to_s.strip

    # validate database parameters
    missing_params = []
    missing_params << "DB_NAME" if db_name.empty?
    missing_params << "DB_USERNAME" if db_user.empty?

    if missing_params.any?
      missing = missing_params.join(", ")
      message = "Missing required database parameters: #{missing}"
      Rails.logger.error message

      # Don't try to construct the URL with missing parameters
      # Just set individual parameters and let Rails handle it
      ENV["DB_PASSWORD"] = db_password

      # Don't raise in production - let Rails use its default connection mechanism
    else
      # Only construct database URL if we have all required parameters
      # Use the postgres:// scheme which is compatible with Rails
      db_port = ENV.fetch("DB_PORT", "5432")
      database_url = "postgres://#{db_user}:#{db_password}@#{db_host}:#{db_port}/#{db_name}"

      # set database url for rails
      ENV["DATABASE_URL"] = database_url

      Rails.logger.info "Database configuration loaded from SSM Parameter Store"
    end
  rescue => e
    Rails.logger.error "Failed to load database configuration from SSM: #{e.message}"
    Rails.logger.error "Make sure AWS credentials are properly configured and the parameter exists"

    # don't crash in development if SSM fails
    raise if Rails.env.production?
  end
end
