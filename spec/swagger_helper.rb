# frozen_string_literal: true

require 'rails_helper'

RSpec.configure do |config|
  # Specify a root folder where Swagger JSON files are generated
  # NOTE: If you're using the rswag-api to serve API descriptions, you'll need
  # to ensure that it's configured to serve Swagger from the same folder
  config.openapi_root = Rails.root.join('public/api').to_s

  # Define one or more Swagger documents and provide global metadata for each one
  # When you run the 'rswag:specs:swaggerize' rake task, the complete Swagger will
  # be generated at the provided relative path under openapi_root
  # By default, the operations defined in spec files are added to the first
  # document below. You can override this behavior by adding a openapi_spec tag to the
  # the root example_group in your specs, e.g. describe '...', openapi_spec: 'v2/swagger.json'
  config.openapi_specs = {
    'v1/spec.yaml' => {
      openapi: '3.0.1',
      info: {
        title: 'tarot api',
        version: 'v1',
        description: 'tarot card reading and interpretation api',
        contact: {
          name: 'API Support',
          url: 'https://github.com/yourusername/tarotapi/issues'
        },
        license: {
          name: 'MIT',
          url: 'https://opensource.org/licenses/MIT'
        }
      },
      paths: {},
      servers: [
        {
          url: '{protocol}://{defaultHost}',
          variables: {
            protocol: {
              default: 'http',
              enum: [ 'http', 'https' ]
            },
            defaultHost: {
              # Use the Docker service name in test environment
              default: ENV['RAILS_ENV'] == 'test' ? 'api:3000' : 'localhost:3000'
            }
          }
        }
      ],
      components: {
        schemas: {},
        securitySchemes: {
          bearerAuth: {
            type: 'http',
            scheme: 'bearer',
            bearerFormat: 'JWT',
            description: 'JWT token obtained from login or registration'
          },
          basicAuth: {
            type: 'http',
            scheme: 'basic',
            description: 'HTTP Basic Auth using email and password'
          },
          apiKeyAuth: {
            type: 'apiKey',
            in: 'header',
            name: 'X-API-Key',
            description: 'API key for agent/service authentication'
          }
        }
      },
      security: [
        { bearerAuth: [] },
        { basicAuth: [] },
        { apiKeyAuth: [] }
      ]
    }
  }

  # Specify the format of the output Swagger file when running 'rswag:specs:swaggerize'.
  # The openapi_specs configuration option has the filename including format in
  # the key, this may want to be changed to avoid putting yaml in json files.
  # Defaults to json. Accepts ':json' and ':yaml'.
  config.openapi_format = :yaml
end
