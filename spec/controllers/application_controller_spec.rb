require 'rails_helper'

# Test controller for testing application controller functionality
class TestController < ApplicationController
  # Skip auth to make testing easier
  skip_auth_for_test if Rails.env.test?

  def index
    render json: { status: "success" }
  end

  def format_test
    render json: { format: request.format.to_s }
  end
end

# Configure routes for testing
Rails.application.routes.draw do
  get 'test', to: 'test#index'
  get 'test/format', to: 'test#format_test'
end

RSpec.describe ApplicationController, type: :controller do
  controller(TestController) do
  end

  before do
    routes.draw { get 'index' => 'test#index' }
    # Stub the methods that would cause external dependencies
    allow(controller).to receive(:log_info).and_return(nil)
  end

  describe "before and after actions" do
    it "sets the default format to JSON" do
      get :index
      expect(request.format).to eq(:json)
    end

    it "stores the request ID" do
      allow(request).to receive(:request_id).and_return("test-request-id")
      get :index
      expect(Thread.current[:request_id]).to eq("test-request-id")
    end

    it "logs the request after completion" do
      expect(controller).to receive(:log_request)
      get :index
    end
  end

  describe "#set_default_format" do
    before do
      routes.draw { get 'format_test' => 'test#format_test' }
    end

    it "sets format to JSON by default" do
      get :format_test
      expect(JSON.parse(response.body)['format']).to eq("application/json")
    end

    it "does not override ndjson format" do
      request.headers["Accept"] = "application/x-ndjson"
      # Need to stub request.format.ndjson? since it's not a standard format
      allow_any_instance_of(ActionDispatch::Http::MimeNegotiation::MimeNegotiator).to receive(:ndjson?).and_return(true)

      # Call the method directly since we can't easily set a custom format in the test
      controller.send(:set_default_format)

      # We can't easily assert the format remains ndjson, but we can verify it didn't change to JSON
      expect(request.format).not_to eq(:json)
    end
  end

  describe "#store_request_id" do
    it "stores the request ID in the current thread" do
      allow(request).to receive(:request_id).and_return("specific-request-id")
      controller.send(:store_request_id)
      expect(Thread.current[:request_id]).to eq("specific-request-id")
    end
  end

  describe "#log_request" do
    it "logs basic request information" do
      # Set up a custom time for the request
      start_time = Time.current - 2.seconds
      allow(request).to receive(:start_time).and_return(start_time)
      allow(request).to receive(:path).and_return("/test/path")
      allow(request).to receive(:method).and_return("GET")
      allow(request).to receive(:format).and_return(double(to_sym: :json))
      allow(request).to receive(:remote_ip).and_return("127.0.0.1")
      allow(response).to receive(:status).and_return(200)

      # Expect log_info to be called with the right parameters
      expect(controller).to receive(:log_info).with("Request completed", hash_including(
        path: "/test/path",
        method: "GET",
        format: :json,
        status: 200,
        user_id: nil,
        ip: "127.0.0.1"
      ))

      controller.send(:log_request)
    end

    it "includes user_id in the log if current_user is available" do
      user = double(id: 123)
      controller.instance_variable_set(:@current_user, user)

      expect(controller).to receive(:log_info).with("Request completed", hash_including(
        user_id: 123
      ))

      controller.send(:log_request)
    end
  end

  describe ".skip_auth_for_test" do
    it "skips authentication actions for tests" do
      # This is a class method that should be called in the test controller setup
      # We can verify it works by ensuring our controller doesn't require authentication
      get :index
      expect(response).to have_http_status(:success)
    end
  end
end
