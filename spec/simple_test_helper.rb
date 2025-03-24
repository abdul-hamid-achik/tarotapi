require 'simplecov'
require 'rspec/core'
require 'webmock/rspec'

SimpleCov.start do
  add_filter '/bin/'
  add_filter '/db/'
  add_filter '/spec/'
  add_filter '/test/'
  add_filter '/config/'
  add_filter '/vendor/'
  add_filter '/lib/tasks/'

  add_group 'controllers', 'app/controllers'
  add_group 'models', 'app/models'
  add_group 'services', 'app/services'
  add_group 'serializers', 'app/serializers'
  add_group 'mailers', 'app/mailers'
  add_group 'jobs', 'app/jobs'
end

# This is a simplified test helper that doesn't require a database connection
# It can be used for isolated unit tests of services and other code that can be tested independently

# Mock Rails.cache
module Rails
  def self.cache
    @cache ||= MockCache.new
  end

  def self.logger
    @logger ||= Logger.new(STDOUT).tap { |l| l.level = Logger::WARN }
  end

  def self.env
    'test'
  end

  class MockCache
    def initialize
      @store = {}
    end

    def fetch(key, options = {}, &block)
      if @store.key?(key)
        @store[key]
      else
        result = yield
        @store[key] = result
        result
      end
    end

    def write(key, value, options = {})
      @store[key] = value
    end

    def read(key)
      @store[key]
    end

    def read_multi(*keys)
      result = {}
      keys.each do |key|
        result[key] = @store[key] if @store.key?(key)
      end
      result
    end

    def delete(key)
      @store.delete(key)
    end

    def delete_matched(pattern)
      # Simple implementation of delete_matched
      regex = Regexp.new(pattern.gsub('*', '.*'))
      @store.keys.each do |key|
        @store.delete(key) if key.match?(regex)
      end
    end

    def clear
      @store.clear
    end
  end
end

# Mock Redis
class MockRedis
  def initialize(options = {})
    @data = {}
    @expirations = {}
  end

  def set(key, value, options = {})
    @data[key] = value

    if options[:ex]
      @expirations[key] = Time.now + options[:ex]
    end

    "OK"
  end

  def get(key)
    check_expiration(key)
    @data[key]
  end

  def del(key)
    @data.delete(key) ? 1 : 0
  end

  def flushdb
    @data = {}
    @expirations = {}
    "OK"
  end

  def scan_each(match: "*", &block)
    pattern = Regexp.new("^#{match.gsub("*", ".*")}$")

    @data.keys.select { |k| k =~ pattern }.each do |key|
      check_expiration(key)
      yield key if @data.key?(key)
    end
  end

  def ping
    "PONG"
  end

  private

  def check_expiration(key)
    if @expirations[key] && @expirations[key] < Time.now
      @data.delete(key)
      @expirations.delete(key)
    end
  end
end

# Define Redis globally for tests
Redis = MockRedis

# Simplify WebMock
WebMock.disable_net_connect!(allow_localhost: true)

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.example_status_persistence_file_path = "spec/examples.txt"
  config.disable_monkey_patching!
  config.order = :random
  Kernel.srand config.seed
end
