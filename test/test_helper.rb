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

# Monkey patch User to support has_secure_password tests
class User
  alias_attribute :password_digest, :encrypted_password

  # This is needed to support the tests that directly call password_digest
  def method_missing(method, *args)
    if method.to_s == "password_digest" && args.present?
      self.encrypted_password
    else
      super
    end
  end

  def respond_to_missing?(method, include_private = false)
    method.to_s == "password_digest" || super
  end
end

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

    # Mock Pundit for controller tests
    def self.mock_pundit
      setup do
        # Store original methods
        @original_authorize = ApplicationController.instance_method(:authorize) if ApplicationController.method_defined?(:authorize)
        @original_policy_scope = ApplicationController.instance_method(:policy_scope) if ApplicationController.method_defined?(:policy_scope)

        # Stub methods
        ApplicationController.class_eval do
          skip_before_action :verify_authorized, raise: false if respond_to?(:verify_authorized)
          skip_after_action :verify_policy_scoped, raise: false if respond_to?(:verify_policy_scoped)

          def pundit_user
            current_user
          end

          # Override Pundit's authorize method
          def authorize(record, query = nil)
            true
          end

          # Override Pundit's policy_scope method
          def policy_scope(scope)
            scope
          end
        end
      end

      teardown do
        # Restore original methods if they existed
        if @original_authorize
          ApplicationController.class_eval do
            define_method(:authorize, @original_authorize)
          end
        end

        if @original_policy_scope
          ApplicationController.class_eval do
            define_method(:policy_scope, @original_policy_scope)
          end
        end
      end
    end

    # Alias cards fixtures as tarot_cards for test compatibility
    def tarot_cards(name)
      cards(name)
    end

    # Add reading_sessions fixture method for tests
    def reading_sessions(name)
      # If we have reading fixtures, return those, otherwise try to create a mock
      if defined?(super)
        super
      else
        # Create a mock fixture on the fly
        @mock_reading_sessions ||= {}

        unless @mock_reading_sessions[name]
          @mock_reading_sessions[name] = ReadingSession.create!(
            session_id: "test-#{name}-#{SecureRandom.hex(4)}",
            question: "Test question for #{name}",
            user: users(:one),
            spread: spreads(:one),
            reading_date: Time.current,
            status: "completed"
          )
        end

        @mock_reading_sessions[name]
      end
    end

    # Add card_readings fixture method for tests
    def card_readings(name)
      # If we have card_readings fixtures, return those, otherwise try to create a mock
      if defined?(super)
        super
      else
        # Create a mock fixture on the fly
        @mock_card_readings ||= {}

        unless @mock_card_readings[name]
          @mock_card_readings[name] = CardReading.create!(
            position: "Test position for #{name}",
            user: users(:one),
            card: cards(:one),
            is_reversed: false,
            reading_date: Time.current
          )
        end

        @mock_card_readings[name]
      end
    end

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
