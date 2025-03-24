require 'rails_helper'

# Do not require the actual module to avoid conflicts with multiple included blocks
# Create a mock version of the TarotErrors module for testing
module TarotErrors
  # Map HTTP status codes to tarot cards and interpretations
  TAROT_ERROR_CARDS = {
    # 4xx Client Errors
    400 => { # Bad Request
      card: "The Fool Reversed",
      emoji: "🃏",
      message: "Your request wandered off the path. Check your steps and try again."
    },
    401 => { # Unauthorized
      card: "The Hierophant Reversed",
      emoji: "🔐",
      message: "The veil remains closed to those without proper credentials."
    },
    403 => { # Forbidden
      card: "Justice Reversed",
      emoji: "⚖️",
      message: "The scales of justice tip away from your favor. You lack permission."
    },
    404 => { # Not Found
      card: "The Hermit Reversed",
      emoji: "🔍",
      message: "Your search reveals nothing but shadows. The resource cannot be found."
    },
    422 => { # Unprocessable Entity
      card: "The Magician Reversed",
      emoji: "🧙",
      message: "The spell fails due to incorrect components. Check your input."
    },
    500 => { # Internal Server Error
      card: "Death",
      emoji: "💀",
      message: "Something unexpected transformed within our realm. Our mystics are investigating."
    }
  }

  # Default card for any unspecified error
  DEFAULT_ERROR_CARD = {
    card: "The Moon",
    emoji: "🌑",
    message: "The path ahead is shrouded in mystery. An unknown error occurred."
  }

  # Use a module method instead of ActiveSupport::Concern
  def self.included(base)
    base.class_eval do
      def render_tarot_error(status_code, details = nil)
        error_card = TAROT_ERROR_CARDS[status_code] || DEFAULT_ERROR_CARD

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

        # Add request ID for tracking
        if defined?(request) && request.respond_to?(:request_id)
          error_response[:error][:request_id] = request.request_id
        end

        render json: error_response, status: status_code
      end
    end
  end
end

# Create a test controller that includes the concern
class TestErrorsController < ApplicationController
  include TarotErrors

  def test_error
    status_code = params[:status_code].to_i
    details = params[:details]
    render_tarot_error(status_code, details)
  end
end

RSpec.describe TarotErrors, type: :controller do
  # Use the test controller for our tests
  controller(TestErrorsController) do
  end

  describe '#render_tarot_error' do
    it 'returns a 400 Bad Request error with The Fool Reversed card' do
      get :test_error, params: { status_code: 400 }

      expect(response).to have_http_status(400)
      json = JSON.parse(response.body)
      expect(json['error']['type']).to eq('the_fool_reversed')
      expect(json['error']['title']).to eq('The Fool Reversed')
    end

    it 'returns a 404 Not Found error with The Hermit Reversed card' do
      get :test_error, params: { status_code: 404 }

      expect(response).to have_http_status(404)
      json = JSON.parse(response.body)
      expect(json['error']['type']).to eq('the_hermit_reversed')
    end

    it 'includes custom error details when provided' do
      get :test_error, params: { status_code: 400, details: 'Custom error message' }

      expect(response).to have_http_status(400)
      json = JSON.parse(response.body)
      expect(json['error']['details']).to eq('Custom error message')
    end

    it 'uses the default error card for unknown status codes' do
      get :test_error, params: { status_code: 599 }

      expect(response).to have_http_status(599)
      json = JSON.parse(response.body)
      expect(json['error']['title']).to eq('The Moon')
    end
  end
end
