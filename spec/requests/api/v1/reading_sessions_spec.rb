require 'rails_helper'

RSpec.describe "Api::V1::ReadingSessions", type: :request do
  describe "POST /api/v1/reading_sessions" do
    let(:user) { User.create! }
    let(:tarot_card1) { TarotCard.create!(name: "The Fool", arcana: "major", description: "New beginnings", rank: "0", symbols: "Cliff, dog") }
    let(:tarot_card2) { TarotCard.create!(name: "The Magician", arcana: "major", description: "Manifestation", rank: "1", symbols: "Infinity symbol") }

    it "creates a new reading session without a spread" do
      expect {
        post "/api/v1/reading_sessions", params: {
          user_id: user.id,
          question: "What does my future hold?",
          card_ids: [ tarot_card1.id, tarot_card2.id ],
          reversed_cards: [ 2 ] # The second card is reversed
        }
      }.to change(ReadingSession, :count).by(1)

      expect(response).to have_http_status(:created)

      json = JSON.parse(response.body)
      expect(json["data"]["attributes"]["question"]).to eq("What does my future hold?")

      # Check that card readings were created
      expect(CardReading.count).to eq(2)

      # Check that the readings are associated with the session
      session_id = json["data"]["id"]
      expect(CardReading.where(reading_session_id: session_id).count).to eq(2)
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

      it "creates a new reading session with a spread" do
        expect {
          post "/api/v1/reading_sessions", params: {
            user_id: user.id,
            spread_id: spread.id,
            question: "What does my career path look like?",
            card_ids: [ tarot_card1.id, tarot_card2.id ],
            reversed_cards: []
          }
        }.to change(ReadingSession, :count).by(1)

        expect(response).to have_http_status(:created)

        json = JSON.parse(response.body)
        expect(json["data"]["attributes"]["question"]).to eq("What does my career path look like?")
        expect(json["data"]["attributes"]["spread_name"]).to eq("Three Card Spread")

        # Check that card readings were created with the correct spread positions
        readings = CardReading.where(reading_session_id: json["data"]["id"])
        expect(readings.count).to eq(2)
        expect(readings.first.spread_position["name"]).to eq("Past")
        expect(readings.second.spread_position["name"]).to eq("Present")
      end
    end
  end

  describe "GET /api/v1/reading_sessions" do
    let(:user) { User.create! }
    let!(:reading_session1) { ReadingSession.create!(user: user, question: "Question 1", reading_date: 1.day.ago) }
    let!(:reading_session2) { ReadingSession.create!(user: user, question: "Question 2", reading_date: 2.days.ago) }

    it "returns all reading sessions for a user" do
      get "/api/v1/reading_sessions", params: { user_id: user.id }

      expect(response).to have_http_status(:success)

      json = JSON.parse(response.body)
      expect(json["data"].size).to eq(2)

      # Sessions should be ordered by created_at desc
      expect(json["data"][0]["attributes"]["question"]).to eq("Question 1")
      expect(json["data"][1]["attributes"]["question"]).to eq("Question 2")
    end
  end

  describe "GET /api/v1/reading_sessions/:id" do
    let(:user) { User.create! }
    let(:reading_session) { ReadingSession.create!(user: user, question: "What does my future hold?") }

    it "returns a specific reading session" do
      get "/api/v1/reading_sessions/#{reading_session.id}"

      expect(response).to have_http_status(:success)

      json = JSON.parse(response.body)
      expect(json["data"]["id"]).to eq(reading_session.id.to_s)
      expect(json["data"]["attributes"]["question"]).to eq("What does my future hold?")
    end
  end

  describe "POST /api/v1/reading_sessions/:id/interpret" do
    let(:user) { User.create! }
    let(:tarot_card) { TarotCard.create!(name: "The Fool", arcana: "major", description: "New beginnings", rank: "0", symbols: "Cliff, dog") }
    let(:reading_session) { ReadingSession.create!(user: user, question: "What does my future hold?") }
    let!(:card_reading) { CardReading.create!(user: user, tarot_card: tarot_card, reading_session: reading_session, position: 1, is_reversed: false) }

    it "generates an interpretation for a reading session" do
      # Mock the LlmService
      llm_service = instance_double(LlmService)
      allow(LlmService).to receive(:instance).and_return(llm_service)
      allow(llm_service).to receive(:interpret_reading).and_return("This is a test interpretation")

      post "/api/v1/reading_sessions/#{reading_session.id}/interpret"

      expect(response).to have_http_status(:success)

      json = JSON.parse(response.body)
      expect(json["interpretation"]).to eq("This is a test interpretation")

      # Check that the reading session was updated with the interpretation
      reading_session.reload
      expect(reading_session.interpretation).to eq("This is a test interpretation")
    end
  end

  describe 'post /api/v1/reading_sessions' do
    let(:spread) { create(:spread) }
    let(:valid_params) do
      {
        spread_id: spread.id,
        question: 'what does the future hold?'
      }
    end

    it 'creates a new reading session' do
      expect {
        post '/api/v1/reading_sessions', params: valid_params
      }.to change(ReadingSession, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(json_response['session_id']).to be_present
      expect(json_response['cards']).to be_present
    end

    context 'with invalid params' do
      it 'returns error for missing spread' do
        post '/api/v1/reading_sessions', params: { question: 'test' }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'get /api/v1/reading_sessions/:session_id' do
    let(:reading_session) { create(:reading_session, :with_card_readings) }

    it 'returns the reading session' do
      get "/api/v1/reading_sessions/#{reading_session.session_id}"

      expect(response).to have_http_status(:ok)
      expect(json_response['session_id']).to eq(reading_session.session_id)
      expect(json_response['cards']).to be_present
    end

    it 'returns not found for invalid session_id' do
      get '/api/v1/reading_sessions/invalid-id'
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'get /api/v1/spreads' do
    before { create_list(:spread, 3) }

    it 'returns all available spreads' do
      get '/api/v1/spreads'

      expect(response).to have_http_status(:ok)
      expect(json_response['spreads'].length).to eq(3)
      expect(json_response['spreads'].first['positions']).to be_present
    end
  end

  private

  def json_response
    JSON.parse(response.body)
  end
end
