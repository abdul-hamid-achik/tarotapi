require_relative '../../simple_test_helper'
require 'rails_helper'

# Create a simple mock TarotErrors that we can test independently
module TestTarotErrors
  TEST_TAROT_ERROR_CARDS = {
    400 => { # Bad Request
      card: "The Fool Reversed",
      emoji: "🃏",
      message: "Your request wandered off the path. Check your steps and try again."
    },
    404 => { # Not Found
      card: "The Hermit Reversed",
      emoji: "🔍",
      message: "Your search reveals nothing but shadows. The resource cannot be found."
    },
    500 => { # Internal Server Error
      card: "Death",
      emoji: "💀",
      message: "Something unexpected transformed within our realm. Our mystics are investigating."
    }
  }

  # Default card for any unspecified error
  TEST_DEFAULT_ERROR_CARD = {
    card: "The Moon",
    emoji: "🌑",
    message: "The path ahead is shrouded in mystery. An unknown error occurred."
  }

  # Simple class to test tarot error functionality
  class ErrorRenderer
    attr_reader :rendered_json, :rendered_status

    def render(options)
      @rendered_json = options[:json]
      @rendered_status = options[:status]
    end

    def render_tarot_error(status_code, details = nil)
      error_card = TEST_TAROT_ERROR_CARDS[status_code] || TEST_DEFAULT_ERROR_CARD

      error_response = {
        error: {
          type: error_card[:card].downcase.gsub(" ", "_"),
          status: status_code,
          title: error_card[:card],
          message: error_card[:message],
          emoji: error_card[:emoji]
        }
      }

      # Add details if provided
      error_response[:error][:details] = details if details

      render json: error_response, status: status_code
    end
  end
end

RSpec.describe "TarotErrors" do
  let(:renderer) { TestTarotErrors::ErrorRenderer.new }

  describe "#render_tarot_error" do
    it 'returns a 400 Bad Request error with The Fool Reversed card' do
      renderer.render_tarot_error(400)

      expect(renderer.rendered_status).to eq(400)
      expect(renderer.rendered_json[:error][:type]).to eq('the_fool_reversed')
      expect(renderer.rendered_json[:error][:title]).to eq('The Fool Reversed')
    end

    it 'returns a 404 Not Found error with The Hermit Reversed card' do
      renderer.render_tarot_error(404)

      expect(renderer.rendered_status).to eq(404)
      expect(renderer.rendered_json[:error][:type]).to eq('the_hermit_reversed')
    end

    it 'includes custom error details when provided' do
      renderer.render_tarot_error(400, 'Custom error message')

      expect(renderer.rendered_status).to eq(400)
      expect(renderer.rendered_json[:error][:details]).to eq('Custom error message')
    end

    it 'uses the default error card for unknown status codes' do
      renderer.render_tarot_error(599)

      expect(renderer.rendered_status).to eq(599)
      expect(renderer.rendered_json[:error][:title]).to eq('The Moon')
    end
  end
end

# Test controller for testing the concern
class TestTarotErrorsController < ApplicationController
  include TarotErrors

  # Override the request_id method to provide a test value
  def request
    req = super
    # This allows the stub in the test to work
    unless @_request_id_set
      def req.request_id
        "test-request-id"
      end
      @_request_id_set = true
    end
    req
  end

  def render_400
    render_tarot_error(400, "Invalid parameter")
  end

  def render_401
    render_tarot_error(401)
  end

  def render_404
    render_tarot_error(404, "User with ID 1 not found")
  end

  def render_422
    render_tarot_error(422, { email: [ "is invalid", "can't be blank" ] })
  end

  def render_500
    render_tarot_error(500, "Server error details")
  end

  def render_unknown
    render_tarot_error(999)
  end
end

# Configure routes for testing
Rails.application.routes.draw do
  get 'test_tarot_errors/400', to: 'test_tarot_errors#render_400'
  get 'test_tarot_errors/401', to: 'test_tarot_errors#render_401'
  get 'test_tarot_errors/404', to: 'test_tarot_errors#render_404'
  get 'test_tarot_errors/422', to: 'test_tarot_errors#render_422'
  get 'test_tarot_errors/500', to: 'test_tarot_errors#render_500'
  get 'test_tarot_errors/unknown', to: 'test_tarot_errors#render_unknown'
end

RSpec.describe TarotErrors, type: :controller do
  controller(TestTarotErrorsController) do
  end

  describe "#render_tarot_error" do
    before do
      allow(request).to receive(:request_id).and_return("test-request-id")
    end

    it "renders a 400 error with the correct tarot card and details" do
      routes.draw { get 'render_400' => 'test_tarot_errors#render_400' }
      get :render_400

      expect(response).to have_http_status(400)
      json_response = JSON.parse(response.body)

      expect(json_response['error']).to include(
        'type' => 'the_fool_reversed',
        'status' => 400,
        'title' => 'The Fool Reversed',
        'message' => "Your request wandered off the path. Check your steps and try again.",
        'emoji' => "🃏",
        'details' => "Invalid parameter",
        'request_id' => "test-request-id"
      )
    end

    it "renders a 401 error with the correct tarot card without details" do
      routes.draw { get 'render_401' => 'test_tarot_errors#render_401' }
      get :render_401

      expect(response).to have_http_status(401)
      json_response = JSON.parse(response.body)

      expect(json_response['error']).to include(
        'type' => 'the_hierophant_reversed',
        'status' => 401,
        'title' => 'The Hierophant Reversed',
        'message' => "The veil remains closed to those without proper credentials.",
        'emoji' => "🔐"
      )
      expect(json_response['error']).not_to have_key('details')
    end

    it "renders a 404 error with the correct tarot card and details" do
      routes.draw { get 'render_404' => 'test_tarot_errors#render_404' }
      get :render_404

      expect(response).to have_http_status(404)
      json_response = JSON.parse(response.body)

      expect(json_response['error']).to include(
        'type' => 'the_hermit_reversed',
        'status' => 404,
        'title' => 'The Hermit Reversed',
        'message' => "Your search reveals nothing but shadows. The resource cannot be found.",
        'emoji' => "🔍",
        'details' => "User with ID 1 not found"
      )
    end

    it "renders a 422 error with complex details object" do
      routes.draw { get 'render_422' => 'test_tarot_errors#render_422' }
      get :render_422

      expect(response).to have_http_status(422)
      json_response = JSON.parse(response.body)

      expect(json_response['error']).to include(
        'type' => 'the_magician_reversed',
        'status' => 422,
        'title' => 'The Magician Reversed',
        'emoji' => "🧙"
      )

      # Check the nested details structure
      expect(json_response['error']['details']).to include(
        'email' => [ "is invalid", "can't be blank" ]
      )
    end

    it "renders a 500 error with the correct tarot card" do
      routes.draw { get 'render_500' => 'test_tarot_errors#render_500' }
      get :render_500

      expect(response).to have_http_status(500)
      json_response = JSON.parse(response.body)

      expect(json_response['error']).to include(
        'type' => 'death',
        'status' => 500,
        'title' => 'Death',
        'emoji' => "💀"
      )
    end

    it "renders the default error card for unknown status code" do
      routes.draw { get 'render_unknown' => 'test_tarot_errors#render_unknown' }
      get :render_unknown

      expect(response).to have_http_status(999)
      json_response = JSON.parse(response.body)

      expect(json_response['error']).to include(
        'type' => 'the_moon',
        'status' => 999,
        'title' => 'The Moon',
        'message' => "The path ahead is shrouded in mystery. An unknown error occurred.",
        'emoji' => "🌑"
      )
    end
  end

  describe "TAROT_ERROR_CARDS constant" do
    it "defines error cards for common HTTP status codes" do
      expect(TarotErrors::TAROT_ERROR_CARDS).to include(
        400, 401, 403, 404, 422, 500
      )
    end

    it "provides card name, emoji, and message for each error" do
      TarotErrors::TAROT_ERROR_CARDS.each do |_status, card_info|
        expect(card_info).to include(:card, :emoji, :message)
      end
    end
  end

  describe "DEFAULT_ERROR_CARD constant" do
    it "defines a default error card" do
      expect(TarotErrors::DEFAULT_ERROR_CARD).to include(
        card: "The Moon",
        emoji: "🌑",
        message: "The path ahead is shrouded in mystery. An unknown error occurred."
      )
    end
  end
end
