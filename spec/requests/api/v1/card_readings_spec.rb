require 'swagger_helper'
require 'rails_helper'

RSpec.describe 'api/v1/card_readings', type: :request do
  let(:id) { create(:card_reading).id }
  let(:reading) do
    spread = create(:spread)
    card = create(:card)
    position_id = spread.positions.first["name"]
    {
      spread_id: spread.id,
      notes: "Test reading",
      positions: [
        {
          position_id: position_id,
          card_id: card.id,
          interpretation: "This card represents your current situation",
          reversed: false
        }
      ]
    }
  end

  path '/api/v1/card_readings' do
    get 'list all card readings' do
      tags 'card readings'
      produces 'application/json'
      parameter name: :spread_id, in: :query, type: :string, format: :uuid, required: false,
                description: 'filter by spread id'

      response '200', 'readings found' do
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
                      spread_id: { type: :string, format: :uuid },
                      notes: { type: :string, nullable: true },
                      positions: {
                        type: :array,
                        items: {
                          type: :object,
                          properties: {
                            position_id: { type: :string, format: :uuid },
                            card_id: { type: :string, format: :uuid },
                            interpretation: { type: :string },
                            reversed: { type: :boolean }
                          },
                          required: %w[position_id card_id interpretation reversed]
                        }
                      },
                      created_at: { type: :string, format: 'date-time' },
                      updated_at: { type: :string, format: 'date-time' }
                    },
                    required: %w[spread_id positions created_at updated_at]
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

    post 'create a card reading' do
      tags 'card readings'
      consumes 'application/json'
      produces 'application/json'
      parameter name: :reading, in: :body, schema: {
        type: :object,
        properties: {
          spread_id: { type: :string, format: :uuid },
          notes: { type: :string, nullable: true },
          positions: {
            type: :array,
            items: {
              type: :object,
              properties: {
                position_id: { type: :string, format: :uuid },
                card_id: { type: :string, format: :uuid },
                interpretation: { type: :string },
                reversed: { type: :boolean }
              },
              required: %w[position_id card_id interpretation reversed]
            }
          }
        },
        required: %w[spread_id positions]
      }

      response '201', 'reading created' do
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
                    spread_id: { type: :string, format: :uuid },
                    notes: { type: :string, nullable: true },
                    positions: {
                      type: :array,
                      items: {
                        type: :object,
                        properties: {
                          position_id: { type: :string, format: :uuid },
                          card_id: { type: :string, format: :uuid },
                          interpretation: { type: :string },
                          reversed: { type: :boolean }
                        },
                        required: %w[position_id card_id interpretation reversed]
                      }
                    },
                    created_at: { type: :string, format: 'date-time' },
                    updated_at: { type: :string, format: 'date-time' }
                  },
                  required: %w[spread_id positions created_at updated_at]
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

  path '/api/v1/card_readings/{id}' do
    parameter name: :id, in: :path, type: :string, format: :uuid

    get 'retrieve a card reading' do
      tags 'card readings'
      produces 'application/json'

      response '200', 'reading found' do
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
                    spread_id: { type: :string, format: :uuid },
                    notes: { type: :string, nullable: true },
                    positions: {
                      type: :array,
                      items: {
                        type: :object,
                        properties: {
                          position_id: { type: :string, format: :uuid },
                          card_id: { type: :string, format: :uuid },
                          interpretation: { type: :string },
                          reversed: { type: :boolean }
                        },
                        required: %w[position_id card_id interpretation reversed]
                      }
                    },
                    created_at: { type: :string, format: 'date-time' },
                    updated_at: { type: :string, format: 'date-time' }
                  },
                  required: %w[spread_id positions created_at updated_at]
                }
              },
              required: %w[id type attributes]
            }
          },
          required: [ 'data' ]

        run_test!
      end

      response '404', 'reading not found' do
        schema type: :object,
          properties: {
            error: { type: :string }
          },
          required: [ 'error' ]

        run_test!
      end
    end

    patch 'update a card reading' do
      tags 'card readings'
      consumes 'application/json'
      produces 'application/json'
      parameter name: :reading, in: :body, schema: {
        type: :object,
        properties: {
          notes: { type: :string, nullable: true },
          positions: {
            type: :array,
            items: {
              type: :object,
              properties: {
                position_id: { type: :string, format: :uuid },
                card_id: { type: :string, format: :uuid },
                interpretation: { type: :string },
                reversed: { type: :boolean }
              },
              required: %w[position_id card_id interpretation reversed]
            }
          }
        }
      }

      response '200', 'reading updated' do
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
                    spread_id: { type: :string, format: :uuid },
                    notes: { type: :string, nullable: true },
                    positions: {
                      type: :array,
                      items: {
                        type: :object,
                        properties: {
                          position_id: { type: :string, format: :uuid },
                          card_id: { type: :string, format: :uuid },
                          interpretation: { type: :string },
                          reversed: { type: :boolean }
                        },
                        required: %w[position_id card_id interpretation reversed]
                      }
                    },
                    created_at: { type: :string, format: 'date-time' },
                    updated_at: { type: :string, format: 'date-time' }
                  },
                  required: %w[spread_id positions created_at updated_at]
                }
              },
              required: %w[id type attributes]
            }
          },
          required: [ 'data' ]

        run_test!
      end

      response '404', 'reading not found' do
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

    delete 'delete a card reading' do
      tags 'card readings'
      produces 'application/json'

      response '204', 'reading deleted' do
        run_test!
      end

      response '404', 'reading not found' do
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

RSpec.describe "Api::V1::CardReadings", type: :request do
  describe "POST /api/v1/card_readings" do
    let(:user) { User.create! }
    let(:tarot_card1) { TarotCard.create!(name: "The Fool", arcana: "major", description: "New beginnings", rank: "0", symbols: "Cliff, dog") }
    let(:tarot_card2) { TarotCard.create!(name: "The Magician", arcana: "major", description: "Manifestation", rank: "1", symbols: "Infinity symbol") }

    it "creates a new reading without a spread" do
      expect {
        post "/api/v1/card_readings", params: {
          user_id: user.id,
          card_ids: [ tarot_card1.id, tarot_card2.id ],
          reversed_cards: [ 2 ] # The second card is reversed
        }
      }.to change(CardReading, :count).by(2)

      expect(response).to have_http_status(:success)

      json = JSON.parse(response.body)
      expect(json["data"].size).to eq(2)

      # First card should not be reversed
      expect(json["data"][0]["attributes"]["is_reversed"]).to eq(false)

      # Second card should be reversed
      expect(json["data"][1]["attributes"]["is_reversed"]).to eq(true)
    end

    context "with a spread" do
      let(:spread) do
        Spread.create!(
          name: "Three Card Spread",
          description: "Past, Present, Future",
          positions: [
            { "name" => "Past", "description" => "What has happened" },
            { "name" => "Present", "description" => "Current situation" },
            { "name" => "Future", "description" => "What will happen" }
          ],
          user: user,
          is_public: true
        )
      end

      it "creates a new reading with a spread" do
        expect {
          post "/api/v1/card_readings", params: {
            user_id: user.id,
            spread_id: spread.id,
            card_ids: [ tarot_card1.id, tarot_card2.id ],
            reversed_cards: []
          }
        }.to change(CardReading, :count).by(2)

        expect(response).to have_http_status(:success)

        json = JSON.parse(response.body)
        expect(json["data"].size).to eq(2)

        # Check that the spread positions are correctly assigned
        expect(json["data"][0]["attributes"]["spread_position"]["name"]).to eq("Past")
        expect(json["data"][1]["attributes"]["spread_position"]["name"]).to eq("Present")
      end
    end
  end

  describe "POST /api/v1/card_readings/interpret" do
    let(:user) { User.create! }
    let(:tarot_card) { TarotCard.create!(name: "The Fool", arcana: "major", description: "New beginnings", rank: "0", symbols: "Cliff, dog") }
    let(:reading) { CardReading.create!(user: user, tarot_card: tarot_card, position: 1, is_reversed: false) }

    it "generates an interpretation for readings" do
      # Mock the LlmService
      llm_service = instance_double(LlmService)
      allow(LlmService).to receive(:instance).and_return(llm_service)
      allow(llm_service).to receive(:interpret_reading).and_return("This is a test interpretation")

      post "/api/v1/card_readings/interpret", params: {
        reading_ids: [ reading.id ]
      }

      expect(response).to have_http_status(:success)

      json = JSON.parse(response.body)
      expect(json["interpretation"]).to eq("This is a test interpretation")

      # Check that the reading was updated with the interpretation
      reading.reload
      expect(reading.interpretation).to eq("This is a test interpretation")
    end
  end
end
