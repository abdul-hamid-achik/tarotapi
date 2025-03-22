require 'swagger_helper'

RSpec.describe 'API V1 Subscriptions', type: :request do
  let(:user) { create(:user) }
  let(:subscription) { create(:subscription, user: user) }
  
  def generate_token_for(user)
    user.create_new_auth_token['access-token']
  end

  path '/api/v1/subscriptions' do
    get 'Lists all subscriptions' do
      tags 'Subscriptions'
      security [{ bearer_auth: [] }]
      produces 'application/json'
      
      response '200', 'subscriptions found' do
        schema type: :array,
          items: {
            type: :object,
            properties: {
              id: { type: :integer },
              status: { type: :string },
              plan_name: { type: :string },
              current_period_end: { type: :string, format: 'date-time' }
            },
            required: ['id', 'status', 'plan_name', 'current_period_end']
          }

        let(:Authorization) { "Bearer #{generate_token_for(user)}" }
        run_test!
      end

      response '401', 'unauthorized' do
        schema type: :object,
          properties: {
            error: { type: :string }
          },
          required: ['error']
        
        run_test!
      end
    end

    post 'Creates a subscription' do
      tags 'Subscriptions'
      security [{ bearer_auth: [] }]
      consumes 'application/json'
      produces 'application/json'
      
      parameter name: :subscription_params, in: :body, schema: {
        type: :object,
        properties: {
          plan_name: { type: :string }
        },
        required: ['plan_name']
      }

      response '201', 'subscription created' do
        schema type: :object,
          properties: {
            subscription_id: { type: :integer },
            status: { type: :string },
            client_secret: { type: :string }
          },
          required: ['subscription_id', 'status', 'client_secret']

        let(:Authorization) { "Bearer #{generate_token_for(user)}" }
        let(:subscription_params) { { plan_name: 'basic' } }
        run_test!
      end

      response '422', 'invalid request' do
        schema type: :object,
          properties: {
            error: { type: :string }
          },
          required: ['error']

        let(:Authorization) { "Bearer #{generate_token_for(user)}" }
        let(:subscription_params) { { plan_name: '' } }
        run_test!
      end
    end
  end

  path '/api/v1/subscriptions/{id}' do
    parameter name: :id, in: :path, type: :string

    get 'Retrieves a subscription' do
      tags 'Subscriptions'
      security [{ bearer_auth: [] }]
      produces 'application/json'

      response '200', 'subscription found' do
        schema type: :object,
          properties: {
            id: { type: :integer },
            plan_name: { type: :string },
            status: { type: :string },
            current_period_end: { type: :string, format: 'date-time' }
          },
          required: ['id', 'plan_name', 'status', 'current_period_end']

        let(:id) { subscription.id }
        let(:Authorization) { "Bearer #{generate_token_for(user)}" }
        run_test!
      end

      response '404', 'subscription not found' do
        schema type: :object,
          properties: {
            error: { type: :string }
          },
          required: ['error']

        let(:id) { 'invalid' }
        let(:Authorization) { "Bearer #{generate_token_for(user)}" }
        run_test!
      end
    end

    delete 'Cancels a subscription' do
      tags 'Subscriptions'
      security [{ bearer_auth: [] }]
      produces 'application/json'

      response '200', 'subscription canceled' do
        schema type: :object,
          properties: {
            id: { type: :integer },
            status: { type: :string },
            ends_at: { type: :string, format: 'date-time' }
          },
          required: ['id', 'status', 'ends_at']

        let(:id) { subscription.id }
        let(:Authorization) { "Bearer #{generate_token_for(user)}" }
        run_test!
      end
    end
  end
end 