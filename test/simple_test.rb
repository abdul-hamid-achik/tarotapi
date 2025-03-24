# A very minimal test that doesn't depend on the database
# Simply requiring the TestAuthentication module directly

require "test/unit"
require_relative "support/test_authentication"

class SimpleTest < Test::Unit::TestCase
  def test_test_authentication_module_is_loaded
    assert defined?(TestAuthentication), "TestAuthentication module should be defined"
  end
end
