require 'swagger_helper'

RSpec.describe 'api/v1/spreads', type: :request do
  path '/api/v1/spreads' do
    get 'list all spreads' do
      tags 'spreads'
      produces 'application/json'
      parameter name: :name, in: :query, type: :string, required: false,
                description: 'filter by spread name'

      response '200', 'spreads found' do
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
                      description: { type: :string },
                      positions: {
                        type: :array,
                        items: {
                          type: :object,
                          properties: {
                            name: { type: :string },
                            description: { type: :string },
                            order: { type: :integer }
                          },
                          required: %w[name description order]
                        }
                      },
                      created_at: { type: :string, format: 'date-time' },
                      updated_at: { type: :string, format: 'date-time' }
                    },
                    required: %w[name description positions created_at updated_at]
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

    post 'create a spread' do
      tags 'spreads'
      consumes 'application/json'
      produces 'application/json'
      parameter name: :spread, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string },
          description: { type: :string },
          positions: {
            type: :array,
            items: {
              type: :object,
              properties: {
                name: { type: :string },
                description: { type: :string },
                order: { type: :integer }
              },
              required: %w[name description order]
            }
          }
        },
        required: %w[name description positions]
      }

      response '201', 'spread created' do
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
                    description: { type: :string },
                    positions: {
                      type: :array,
                      items: {
                        type: :object,
                        properties: {
                          name: { type: :string },
                          description: { type: :string },
                          order: { type: :integer }
                        },
                        required: %w[name description order]
                      }
                    },
                    created_at: { type: :string, format: 'date-time' },
                    updated_at: { type: :string, format: 'date-time' }
                  },
                  required: %w[name description positions created_at updated_at]
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

  path '/api/v1/spreads/{id}' do
    parameter name: :id, in: :path, type: :string, format: :uuid

    get 'retrieve a spread' do
      tags 'spreads'
      produces 'application/json'

      response '200', 'spread found' do
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
                    description: { type: :string },
                    positions: {
                      type: :array,
                      items: {
                        type: :object,
                        properties: {
                          name: { type: :string },
                          description: { type: :string },
                          order: { type: :integer }
                        },
                        required: %w[name description order]
                      }
                    },
                    created_at: { type: :string, format: 'date-time' },
                    updated_at: { type: :string, format: 'date-time' }
                  },
                  required: %w[name description positions created_at updated_at]
                }
              },
              required: %w[id type attributes]
            }
          },
          required: [ 'data' ]

        run_test!
      end

      response '404', 'spread not found' do
        schema type: :object,
          properties: {
            error: { type: :string }
          },
          required: [ 'error' ]

        run_test!
      end
    end

    patch 'update a spread' do
      tags 'spreads'
      consumes 'application/json'
      produces 'application/json'
      parameter name: :spread, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string },
          description: { type: :string },
          positions: {
            type: :array,
            items: {
              type: :object,
              properties: {
                name: { type: :string },
                description: { type: :string },
                order: { type: :integer }
              },
              required: %w[name description order]
            }
          }
        }
      }

      response '200', 'spread updated' do
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
                    description: { type: :string },
                    positions: {
                      type: :array,
                      items: {
                        type: :object,
                        properties: {
                          name: { type: :string },
                          description: { type: :string },
                          order: { type: :integer }
                        },
                        required: %w[name description order]
                      }
                    },
                    created_at: { type: :string, format: 'date-time' },
                    updated_at: { type: :string, format: 'date-time' }
                  },
                  required: %w[name description positions created_at updated_at]
                }
              },
              required: %w[id type attributes]
            }
          },
          required: [ 'data' ]

        run_test!
      end

      response '404', 'spread not found' do
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

    delete 'delete a spread' do
      tags 'spreads'
      produces 'application/json'

      response '204', 'spread deleted' do
        run_test!
      end

      response '404', 'spread not found' do
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
