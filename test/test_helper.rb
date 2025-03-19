require "simplecov"
SimpleCov.start "rails" do
  add_filter "/bin/"
  add_filter "/db/"
  add_filter "/spec/"
  add_filter "/test/"
  add_filter "/config/"
  add_filter "/vendor/"
  add_filter "/lib/tasks/"

  add_group "controllers", "app/controllers"
  add_group "models", "app/models"
  add_group "services", "app/services"
  add_group "serializers", "app/serializers"
  add_group "mailers", "app/mailers"
  add_group "jobs", "app/jobs"
end

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

# Monkey patch ActiveRecord::FixtureSet to handle session_id in fixtures
module ActiveRecord
  class FixtureSet
    class << self
      alias_method :orig_create_fixtures, :create_fixtures

      def create_fixtures(fixtures_directory, fixture_set_names, class_names = {}, config = ActiveRecord::Base)
        # Original method
        fixture_sets = orig_create_fixtures(fixtures_directory, fixture_set_names, class_names, config)

        # Add session_id to ReadingSession records
        if defined?(ReadingSession) && fixture_set_names.include?("reading_sessions")
          # Find reading_session fixture set
          reading_session_fixture_set = fixture_sets.find { |fs| fs.name == "reading_sessions" }

          # Get connection
          connection = ActiveRecord::Base.connection

          # Update all records that have null session_id
          connection.execute(<<~SQL)
            UPDATE reading_sessions#{' '}
            SET session_id = 'test-' || id || '-' || md5(random()::text)
            WHERE session_id IS NULL
          SQL
        end

        fixture_sets
      end
    end
  end
end

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...

    setup do
      # Ensure all ReadingSession records have a session_id
      if defined?(ReadingSession)
        ReadingSession.where(session_id: nil).find_each do |session|
          session.update_column(:session_id, "test-#{session.id}-#{SecureRandom.hex(4)}")
        end
      end
    end
  end
end
