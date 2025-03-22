require 'swagger_helper'

RSpec.describe 'api/v1/auth', type: :request do
  path '/api/v1/auth/register' do
    post 'Register a new user' do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'
      parameter name: :user, in: :body, schema: {
        type: :object,
        properties: {
          user: {
            type: :object,
            properties: {
              email: { type: :string, format: :email },
              password: { type: :string, format: :password },
              password_confirmation: { type: :string, format: :password }
            },
            required: [ 'email', 'password', 'password_confirmation' ]
          }
        },
        required: [ 'user' ]
      }

      response '201', 'user registered' do
        let(:user) { { user: { email: 'test@example.com', password: 'password123', password_confirmation: 'password123' } } }

        schema type: :object,
          properties: {
            token: { type: :string },
            refresh_token: { type: :string },
            user: {
              type: :object,
              properties: {
                id: { type: :string, format: :uuid },
                email: { type: :string, format: :email }
              },
              required: [ 'id', 'email' ]
            }
          },
          required: [ 'token', 'refresh_token', 'user' ]

        run_test!
      end

      response '422', 'invalid request' do
        let(:user) { { user: { email: 'invalid', password: 'short', password_confirmation: 'mismatch' } } }

        schema type: :object,
          properties: {
            errors: {
              type: :array,
              items: { type: :string }
            }
          },
          required: [ 'errors' ]

        run_test!
      end
    end
  end

  path '/api/v1/auth/login' do
    post 'Login with email and password' do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'
      parameter name: :credentials, in: :body, schema: {
        type: :object,
        properties: {
          email: { type: :string, format: :email },
          password: { type: :string, format: :password }
        },
        required: [ 'email', 'password' ]
      }

      response '200', 'login successful' do
        let(:credentials) { { email: 'test@example.com', password: 'password123' } }

        schema type: :object,
          properties: {
            token: { type: :string },
            refresh_token: { type: :string },
            user: {
              type: :object,
              properties: {
                id: { type: :string, format: :uuid },
                email: { type: :string, format: :email }
              },
              required: [ 'id', 'email' ]
            }
          },
          required: [ 'token', 'refresh_token', 'user' ]

        run_test!
      end

      response '401', 'invalid credentials' do
        let(:credentials) { { email: 'wrong@example.com', password: 'wrongpassword' } }

        schema type: :object,
          properties: {
            error: { type: :string }
          },
          required: [ 'error' ]

        run_test!
      end
    end
  end

  path '/api/v1/auth/refresh' do
    post 'Refresh authentication token' do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'
      parameter name: :refresh_token_param, in: :body, schema: {
        type: :object,
        properties: {
          refresh_token: { type: :string }
        },
        required: [ 'refresh_token' ]
      }

      response '200', 'token refreshed' do
        let(:refresh_token_param) { { refresh_token: 'valid_refresh_token' } }

        schema type: :object,
          properties: {
            token: { type: :string }
          },
          required: [ 'token' ]

        run_test!
      end

      response '401', 'invalid refresh token' do
        let(:refresh_token_param) { { refresh_token: 'invalid_refresh_token' } }

        schema type: :object,
          properties: {
            error: { type: :string }
          },
          required: [ 'error' ]

        run_test!
      end
    end
  end

  path '/api/v1/auth/profile' do
    get 'Get user profile' do
      tags 'Authentication'
      security [ bearerAuth: [] ]
      produces 'application/json'

      response '200', 'profile retrieved' do
        schema type: :object,
          properties: {
            id: { type: :string, format: :uuid },
            email: { type: :string, format: :email },
            identity_provider: { type: :string, nullable: true }
          },
          required: [ 'id', 'email' ]

        let(:Authorization) { 'Bearer valid_token' }
        run_test!
      end

      response '401', 'unauthorized' do
        schema type: :object,
          properties: {
            error: { type: :string }
          },
          required: [ 'error' ]

        let(:Authorization) { 'Bearer invalid_token' }
        run_test!
      end
    end
  end

  path '/api/v1/auth/agent' do
    post 'Create an agent API user' do
      tags 'Authentication'
      security [ bearerAuth: [] ]
      consumes 'application/json'
      produces 'application/json'
      parameter name: :agent, in: :body, schema: {
        type: :object,
        properties: {
          email: { type: :string, format: :email },
          password: { type: :string, format: :password },
          password_confirmation: { type: :string, format: :password }
        },
        required: [ 'email', 'password', 'password_confirmation' ]
      }

      response '201', 'agent created' do
        let(:agent) { { email: 'agent@example.com', password: 'password123', password_confirmation: 'password123' } }
        let(:Authorization) { 'Bearer valid_token' }

        schema type: :object,
          properties: {
            agent_id: { type: :string, format: :uuid },
            external_id: { type: :string },
            email: { type: :string, format: :email },
            api_token: { type: :string }
          },
          required: [ 'agent_id', 'external_id', 'email', 'api_token' ]

        run_test!
      end

      response '401', 'unauthorized' do
        let(:agent) { { email: 'agent@example.com', password: 'password123', password_confirmation: 'password123' } }
        let(:Authorization) { 'Bearer invalid_token' }

        schema type: :object,
          properties: {
            error: { type: :string }
          },
          required: [ 'error' ]

        run_test!
      end

      response '422', 'invalid request' do
        let(:agent) { { email: 'invalid', password: 'short', password_confirmation: 'mismatch' } }
        let(:Authorization) { 'Bearer valid_token' }

        schema type: :object,
          properties: {
            errors: {
              type: :array,
              items: { type: :string }
            }
          },
          required: [ 'errors' ]

        run_test!
      end
    end
  end
end
