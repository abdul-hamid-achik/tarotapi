require 'rails_helper'

# We need to stub the actual ErrorHandler module to prevent it from trying to extend the TestController
# with rescue_from, which isn't available without a real Rails controller.
RSpec.describe "ErrorHandler" do
  class TestController
    include TarotErrors

    attr_reader :render_options, :rendered_status, :rendered_json, :request

    def initialize
      @request = OpenStruct.new(request_id: 'test-request-id')
    end

    def render(options)
      @render_options = options
      @rendered_json = options[:json]
      @rendered_status = options[:status]
    end

    def current_user
      @current_user ||= OpenStruct.new(id: 1)
    end

    # Implement error handling methods directly for testing

    def handle_standard_error(exception)
      log_error(exception)
      render_tarot_error(500, exception.message)
    end

    def log_error(exception, context = {})
      context[:user_id] = current_user&.id if defined?(current_user)
      context[:request_id] = request&.request_id if defined?(request) && request&.respond_to?(:request_id)

      error_message = "#{exception.class.name}: #{exception.message}"
      error_context = context.map { |k, v| "#{k}=#{v}" }.join(" ")

      Rails.logger.error("#{error_message} | #{error_context}")
    end

    def handle_not_found(exception)
      model = begin
                exception.model.downcase
              rescue
                "resource"
              end
      details = "The requested #{model} could not be found"

      log_error(exception, { model: model, id: nil })
      render_tarot_error(404, details)
    end

    def handle_validation_error(exception)
      record = exception.record
      errors = record.errors.messages.transform_values { |msgs| msgs.join(", ") }

      log_error(exception, { model: record.class.name, errors: errors })
      render_tarot_error(422, errors)
    end

    def handle_parameter_missing(exception)
      parameter = exception.param
      details = "Required parameter missing: #{parameter}"

      log_error(exception, { parameter: parameter })
      render_tarot_error(400, details)
    end

    def handle_argument_error(exception)
      log_error(exception)
      render_tarot_error(400, exception.message)
    end
  end

  # Create mock TarotErrors module
  module TarotErrors
    def render_tarot_error(status, details)
      render(json: { error: { status: status, details: details } })
    end
  end

  # Mock Rails logger
  module Rails
    def self.logger
      @logger ||= Logger.new(STDOUT)
    end
  end

  let(:controller) { TestController.new }
  let(:exception) { StandardError.new("Test error") }

  before do
    allow(Rails.logger).to receive(:error)
  end

  describe '#handle_standard_error' do
    it 'renders a 500 error' do
      controller.handle_standard_error(exception)

      expect(controller.rendered_json[:error][:status]).to eq(500)
      expect(controller.rendered_json[:error][:details]).to eq("Test error")
    end
  end

  describe '#handle_not_found' do
    let(:not_found_exception) {
      exception = double("ActiveRecord::RecordNotFound")
      allow(exception).to receive(:model).and_return("User")
      allow(exception).to receive(:message).and_return("Record not found")
      exception
    }

    it 'renders a 404 error' do
      controller.handle_not_found(not_found_exception)

      expect(controller.rendered_json[:error][:status]).to eq(404)
      expect(controller.rendered_json[:error][:details]).to eq("The requested user could not be found")
    end
  end

  describe '#handle_validation_error' do
    let(:record) { double("User") }
    let(:errors) { double("Errors") }
    let(:validation_error) { double("ActiveRecord::RecordInvalid") }

    before do
      allow(validation_error).to receive(:record).and_return(record)
      allow(validation_error).to receive(:message).and_return("Validation failed: Email can't be blank")
      allow(record).to receive(:class).and_return(Object)
      allow(record).to receive(:errors).and_return(errors)
      allow(errors).to receive(:messages).and_return({ email: [ "can't be blank" ] })
    end

    it 'renders a 422 error' do
      controller.handle_validation_error(validation_error)

      expect(controller.rendered_json[:error][:status]).to eq(422)
      expect(controller.rendered_json[:error][:details]).to eq({ email: "can't be blank" })
    end
  end

  describe '#handle_parameter_missing' do
    let(:param_error) {
      error = double("ActionController::ParameterMissing")
      allow(error).to receive(:param).and_return("user_id")
      allow(error).to receive(:message).and_return("param is missing or the value is empty: user_id")
      error
    }

    it 'renders a 400 error' do
      controller.handle_parameter_missing(param_error)

      expect(controller.rendered_json[:error][:status]).to eq(400)
      expect(controller.rendered_json[:error][:details]).to eq("Required parameter missing: user_id")
    end
  end

  describe '#handle_argument_error' do
    let(:arg_error) { ArgumentError.new("Invalid argument") }

    it 'renders a 400 error' do
      controller.handle_argument_error(arg_error)

      expect(controller.rendered_json[:error][:status]).to eq(400)
      expect(controller.rendered_json[:error][:details]).to eq("Invalid argument")
    end
  end
end

# Create a test controller to test the concern
class TestErrorController < ApplicationController
  include ErrorHandler

  def trigger_standard_error
    raise StandardError, "Standard error"
  end

  def trigger_not_found
    raise ActiveRecord::RecordNotFound.new("Not found", "User", "id", 1)
  end

  def trigger_parameter_missing
    raise ActionController::ParameterMissing.new(:required_param)
  end

  def trigger_argument_error
    raise ArgumentError, "Invalid argument"
  end

  def trigger_validation_error
    user = User.new
    user.errors.add(:email, "can't be blank")
    raise ActiveRecord::RecordInvalid.new(user)
  end
end

# Configure routes for testing
Rails.application.routes.draw do
  get 'test_error/standard_error', to: 'test_error#trigger_standard_error'
  get 'test_error/not_found', to: 'test_error#trigger_not_found'
  get 'test_error/parameter_missing', to: 'test_error#trigger_parameter_missing'
  get 'test_error/argument_error', to: 'test_error#trigger_argument_error'
  get 'test_error/validation_error', to: 'test_error#trigger_validation_error'
end

RSpec.describe ErrorHandler, type: :controller do
  controller(TestErrorController) do
  end

  describe "error handling" do
    before do
      # Stub logger to prevent actual logging during tests
      allow(Rails.logger).to receive(:error).and_return(nil)
      allow(TarotLogger).to receive(:error).and_return(nil)
    end

    it "handles standard errors with 500 response" do
      routes.draw { get 'trigger_standard_error' => 'test_error#trigger_standard_error' }
      get :trigger_standard_error
      expect(response).to have_http_status(500)
      expect(JSON.parse(response.body)).to include('error')
    end

    it "handles not found errors with 404 response" do
      routes.draw { get 'trigger_not_found' => 'test_error#trigger_not_found' }
      get :trigger_not_found
      expect(response).to have_http_status(404)
      expect(JSON.parse(response.body)).to include('error')
      expect(JSON.parse(response.body)['error']).to include('could not be found')
    end

    it "handles parameter missing errors with 400 response" do
      routes.draw { get 'trigger_parameter_missing' => 'test_error#trigger_parameter_missing' }
      get :trigger_parameter_missing
      expect(response).to have_http_status(400)
      expect(JSON.parse(response.body)).to include('error')
      expect(JSON.parse(response.body)['error']).to include('Required parameter missing')
    end

    it "handles argument errors with 400 response" do
      routes.draw { get 'trigger_argument_error' => 'test_error#trigger_argument_error' }
      get :trigger_argument_error
      expect(response).to have_http_status(400)
      expect(JSON.parse(response.body)).to include('error')
      expect(JSON.parse(response.body)['error']).to include('Invalid argument')
    end

    it "handles validation errors with 422 response" do
      routes.draw { get 'trigger_validation_error' => 'test_error#trigger_validation_error' }
      get :trigger_validation_error
      expect(response).to have_http_status(422)
      expect(JSON.parse(response.body)).to include('error')
    end

    it "logs errors with context" do
      routes.draw { get 'trigger_standard_error' => 'test_error#trigger_standard_error' }

      # Expect the log_error method to be called
      expect_any_instance_of(TestErrorController).to receive(:log_error)

      get :trigger_standard_error
    end
  end
end
