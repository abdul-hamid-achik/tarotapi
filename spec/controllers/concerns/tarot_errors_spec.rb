require_relative '../../simple_test_helper'

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
