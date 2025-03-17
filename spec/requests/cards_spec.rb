require 'swagger_helper'

RSpec.describe 'cards api', type: :request do
  path '/cards/{id}' do
    get 'retrieves a card' do
      tags 'cards'
      produces 'application/json'
      parameter name: :id, in: :path, type: :string, description: 'id of the card'

      response '200', 'card found' do
        schema type: :object,
          properties: {
            data: {
              type: :object,
              properties: {
                id: { type: :string },
                type: { type: :string },
                attributes: {
                  type: :object,
                  properties: {
                    name: { type: :string },
                    description: { type: :string },
                    image_url: { type: :string, nullable: true },
                    created_at: { type: :string, format: 'date-time' },
                    updated_at: { type: :string, format: 'date-time' }
                  },
                  required: %w[name description created_at updated_at]
                }
              },
              required: %w[id type attributes]
            }
          },
          required: ['data']

        let(:id) { create(:card).id }
        run_test!
      end

      response '404', 'card not found' do
        schema type: :object,
          properties: {
            error: { type: :string }
          },
          required: ['error']

        let(:id) { 'invalid' }
        run_test!
      end
    end
  end
end 