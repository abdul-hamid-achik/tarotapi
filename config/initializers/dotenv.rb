# load environment variables from .env files
# only in development and test environments
if Rails.env.development? || Rails.env.test?
  require "dotenv"

  # specify the files to load in order of preference
  Dotenv.load(
    ".env.#{Rails.env}.local",
    ".env.#{Rails.env}",
    ".env.local",
    ".env",
    ".env.example",
  )
end
