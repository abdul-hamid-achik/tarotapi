Rswag::Api.configure do |c|
  # Specify a root folder where Swagger JSON files are located
  # This is used by the Swagger middleware to serve requests for API descriptions
  # NOTE: If you're using rswag-specs to generate Swagger, you'll need to ensure
  # that it's configured to generate files in the same folder
  c.openapi_root = Rails.root.to_s + "/public/api"

  # Inject security schemes and other OpenAPI enhancements
  c.swagger_filter = lambda { |swagger, env|
    # Ensure components section exists
    swagger["components"] ||= {}

    # Add security schemes
    swagger["components"]["securitySchemes"] = {
      "bearerAuth" => {
        "type" => "http",
        "scheme" => "bearer",
        "bearerFormat" => "JWT",
        "description" => "JWT token obtained from login or registration"
      },
      "basicAuth" => {
        "type" => "http",
        "scheme" => "basic",
        "description" => "HTTP Basic Auth using email and password"
      },
      "apiKeyAuth" => {
        "type" => "apiKey",
        "in" => "header",
        "name" => "X-API-Key",
        "description" => "API key for agent/service authentication"
      }
    }

    # Add global security requirement
    swagger["security"] ||= [
      { "bearerAuth" => [] },
      { "basicAuth" => [] },
      { "apiKeyAuth" => [] }
    ]

    # Ensure info section has proper contact and license info
    swagger["info"]["contact"] ||= {
      "name" => "API Support",
      "url" => "https://github.com/yourusername/tarotapi/issues"
    }

    swagger["info"]["license"] ||= {
      "name" => "MIT",
      "url" => "https://opensource.org/licenses/MIT"
    }

    swagger
  }
end
