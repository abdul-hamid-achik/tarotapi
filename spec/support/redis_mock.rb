# Mock Redis for testing
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

  private

  def check_expiration(key)
    if @expirations[key] && @expirations[key] < Time.now
      @data.delete(key)
      @expirations.delete(key)
    end
  end
end

# Override Redis with our mock in test environment
if Rails.env.test?
  Redis = MockRedis
end
