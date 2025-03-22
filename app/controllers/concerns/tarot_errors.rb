module TarotErrors
  extend ActiveSupport::Concern

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
    405 => { # Method Not Allowed
      card: "The Emperor Reversed",
      emoji: "👑",
      message: "The Emperor rejects your approach. This method is not allowed."
    },
    406 => { # Not Acceptable
      card: "The Moon Reversed",
      emoji: "🌙",
      message: "Illusions cloud your perception. Your request format is not acceptable."
    },
    408 => { # Request Timeout
      card: "Wheel of Fortune Reversed",
      emoji: "⏳",
      message: "The wheel spins but time runs out. Your request took too long."
    },
    409 => { # Conflict
      card: "The Tower",
      emoji: "🗼",
      message: "Conflict disrupts the harmony. Your request contradicts existing state."
    },
    422 => { # Unprocessable Entity
      card: "The Magician Reversed",
      emoji: "🧙",
      message: "The spell fails due to incorrect components. Check your input."
    },
    429 => { # Too Many Requests
      card: "Temperance Reversed",
      emoji: "🔥",
      message: "Patience is a virtue. You've made too many requests too quickly."
    },

    # 5xx Server Errors
    500 => { # Internal Server Error
      card: "Death",
      emoji: "💀",
      message: "Something unexpected transformed within our realm. Our mystics are investigating."
    },
    501 => { # Not Implemented
      card: "The Star Reversed",
      emoji: "⭐",
      message: "This future hasn't yet been written in the stars. Feature not implemented."
    },
    502 => { # Bad Gateway
      card: "The Chariot Reversed",
      emoji: "🏎️",
      message: "The chariot's path is blocked. Bad gateway to external service."
    },
    503 => { # Service Unavailable
      card: "The Sun Reversed",
      emoji: "🌥️",
      message: "The sun retreats behind clouds. Service temporarily unavailable."
    },
    504 => { # Gateway Timeout
      card: "The Hanged Man",
      emoji: "⌛",
      message: "Like The Hanged Man, we're suspended in wait. Gateway timeout."
    }
  }

  # Default card for any unspecified error
  DEFAULT_ERROR_CARD = {
    card: "The Moon",
    emoji: "🌑",
    message: "The path ahead is shrouded in mystery. An unknown error occurred."
  }

  included do
    # Add this method to render a tarot-themed error response
    def render_tarot_error(status_code, details = nil)
      error_card = TAROT_ERROR_CARDS[status_code] || DEFAULT_ERROR_CARD
      
      error_response = {
        error: {
          type: error_card[:card].downcase.gsub(' ', '_'),
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