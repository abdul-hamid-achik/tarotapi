require 'cucumber/rails'
require 'factory_bot'
require 'database_cleaner/active_record'
require 'rack/test'
require_relative 'api_helpers'

# prevent database truncation if the environment is production
begin
  raise 'cucumber seeds run against production database' if Rails.env.production?
rescue NameError
  raise 'you need to add database_cleaner to your gemfile (in the :test group) if you wish to use it.'
end

# configure database cleaner
DatabaseCleaner.strategy = :truncation

# hooks for database cleaning
Before do
  DatabaseCleaner.clean
  
  # create identity providers
  IdentityProvider.anonymous
  IdentityProvider.registered
  IdentityProvider.agent
  
  Rails.application.routes.default_url_options[:host] = 'example.org'
  host! 'example.org'
  header 'Content-Type', 'application/json'
  header 'Accept', 'application/json'
end

After do
  DatabaseCleaner.clean
end

# configure factorybot
World(FactoryBot::Syntax::Methods)

# configure rack/test
World(Rack::Test::Methods)

def app
  Rails.application
end

# disable rails rescue
ActionController::Base.allow_rescue = false

# ensure cache classes is enabled for test environment
Rails.application.config.cache_classes = true

# configure javascript strategy
Cucumber::Rails::Database.javascript_strategy = :truncation

# allow all hosts in test
Rails.application.configure do
  config.hosts.clear
end
