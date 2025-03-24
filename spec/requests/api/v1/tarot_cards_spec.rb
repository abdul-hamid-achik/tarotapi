require 'swagger_helper'

RSpec.describe 'api/v1/tarot_cards', type: :request do
  let(:id) { create(:card).id }
  let(:card) { { name: 'The Fool', arcana: 'Major', suit: 'none', description: 'New beginnings', rank: '0', symbols: 'White rose' } }

  path '/api/v1/tarot_cards' do
    get 'list all tarot cards' do
      tags 'tarot cards'
      produces 'application/json'
      parameter name: :arcana, in: :query, type: :string, required: false,
                description: 'filter by arcana (Major/Minor)'
      parameter name: :suit, in: :query, type: :string, required: false,
                description: 'filter by suit (none/Wands/Cups/Swords/Pentacles)'

      response '200', 'cards found' do
        schema type: :object,
          properties: {
            data: {
              type: :array,
              items: {
                type: :object,
                properties: {
                  id: { type: :string, format: :uuid },
                  type: { type: :string },
                  attributes: {
                    type: :object,
                    properties: {
                      name: { type: :string },
                      arcana: { type: :string, enum: [ 'Major', 'Minor' ] },
                      suit: { type: :string, enum: [ 'none', 'Wands', 'Cups', 'Swords', 'Pentacles' ] },
                      description: { type: :string },
                      rank: { type: :string },
                      symbols: { type: :string },
                      image_url: { type: :string, nullable: true },
                      created_at: { type: :string, format: 'date-time' },
                      updated_at: { type: :string, format: 'date-time' }
                    },
                    required: %w[name arcana suit description rank symbols created_at updated_at]
                  }
                },
                required: %w[id type attributes]
              }
            }
          },
          required: [ 'data' ]

        run_test!
      end
    end

    post 'create a tarot card' do
      tags 'tarot cards'
      consumes 'application/json'
      produces 'application/json'
      parameter name: :card, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string },
          arcana: { type: :string, enum: [ 'Major', 'Minor' ] },
          suit: { type: :string, enum: [ 'none', 'Wands', 'Cups', 'Swords', 'Pentacles' ] },
          description: { type: :string },
          rank: { type: :string },
          symbols: { type: :string },
          image: { type: :string, format: :binary, nullable: true }
        },
        required: %w[name arcana suit description rank symbols]
      }

      response '201', 'card created' do
        schema type: :object,
          properties: {
            data: {
              type: :object,
              properties: {
                id: { type: :string, format: :uuid },
                type: { type: :string },
                attributes: {
                  type: :object,
                  properties: {
                    name: { type: :string },
                    arcana: { type: :string },
                    suit: { type: :string },
                    description: { type: :string },
                    rank: { type: :string },
                    symbols: { type: :string },
                    image_url: { type: :string, nullable: true },
                    created_at: { type: :string, format: 'date-time' },
                    updated_at: { type: :string, format: 'date-time' }
                  },
                  required: %w[name arcana suit description rank symbols created_at updated_at]
                }
              },
              required: %w[id type attributes]
            }
          },
          required: [ 'data' ]

        run_test!
      end

      response '422', 'invalid request' do
        schema type: :object,
          properties: {
            errors: {
              type: :array,
              items: {
                type: :object,
                properties: {
                  source: { type: :string },
                  detail: { type: :string }
                }
              }
            }
          }

        run_test!
      end
    end
  end

  path '/api/v1/tarot_cards/{id}' do
    parameter name: :id, in: :path, type: :string, format: :uuid

    get 'retrieve a tarot card' do
      tags 'tarot cards'
      produces 'application/json'

      response '200', 'card found' do
        schema type: :object,
          properties: {
            data: {
              type: :object,
              properties: {
                id: { type: :string, format: :uuid },
                type: { type: :string },
                attributes: {
                  type: :object,
                  properties: {
                    name: { type: :string },
                    arcana: { type: :string },
                    suit: { type: :string },
                    description: { type: :string },
                    rank: { type: :string },
                    symbols: { type: :string },
                    image_url: { type: :string, nullable: true },
                    created_at: { type: :string, format: 'date-time' },
                    updated_at: { type: :string, format: 'date-time' }
                  },
                  required: %w[name arcana suit description rank symbols created_at updated_at]
                }
              },
              required: %w[id type attributes]
            }
          },
          required: [ 'data' ]

        run_test!
      end

      response '404', 'card not found' do
        schema type: :object,
          properties: {
            error: { type: :string }
          },
          required: [ 'error' ]

        run_test!
      end
    end

    patch 'update a tarot card' do
      tags 'tarot cards'
      consumes 'application/json'
      produces 'application/json'
      parameter name: :card, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string },
          arcana: { type: :string, enum: [ 'Major', 'Minor' ] },
          suit: { type: :string, enum: [ 'none', 'Wands', 'Cups', 'Swords', 'Pentacles' ] },
          description: { type: :string },
          rank: { type: :string },
          symbols: { type: :string },
          image: { type: :string, format: :binary, nullable: true }
        }
      }

      response '200', 'card updated' do
        schema type: :object,
          properties: {
            data: {
              type: :object,
              properties: {
                id: { type: :string, format: :uuid },
                type: { type: :string },
                attributes: {
                  type: :object,
                  properties: {
                    name: { type: :string },
                    arcana: { type: :string },
                    suit: { type: :string },
                    description: { type: :string },
                    rank: { type: :string },
                    symbols: { type: :string },
                    image_url: { type: :string, nullable: true },
                    created_at: { type: :string, format: 'date-time' },
                    updated_at: { type: :string, format: 'date-time' }
                  },
                  required: %w[name arcana suit description rank symbols created_at updated_at]
                }
              },
              required: %w[id type attributes]
            }
          },
          required: [ 'data' ]

        run_test!
      end

      response '404', 'card not found' do
        schema type: :object,
          properties: {
            error: { type: :string }
          },
          required: [ 'error' ]

        run_test!
      end

      response '422', 'invalid request' do
        schema type: :object,
          properties: {
            errors: {
              type: :array,
              items: {
                type: :object,
                properties: {
                  source: { type: :string },
                  detail: { type: :string }
                }
              }
            }
          }

        run_test!
      end
    end

    delete 'delete a tarot card' do
      tags 'tarot cards'
      produces 'application/json'

      response '204', 'card deleted' do
        run_test!
      end

      response '404', 'card not found' do
        schema type: :object,
          properties: {
            error: { type: :string }
          },
          required: [ 'error' ]

        run_test!
      end
    end
  end
end
