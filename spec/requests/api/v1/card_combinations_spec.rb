require 'rails_helper'

RSpec.describe "API V1 Card Combinations", type: :request do
  let!(:user) { create(:user) }
  let!(:auth_headers) { user.create_new_auth_token }
  let!(:card1) { create(:card, name: "The Fool", arcana: "major", rank: 0) }
  let!(:card2) { create(:card, name: "The Tower", arcana: "major", rank: 16) }
  let!(:card3) { create(:card, name: "Nine of Cups", arcana: "minor", rank: 9, suit: "cups") }
  let(:reading_service) { instance_double(ReadingService) }

  before do
    allow(ReadingService).to receive(:new).and_return(reading_service)
    allow(reading_service).to receive(:analyze_card_combination).and_return("These cards together suggest a sudden opportunity for change.")
  end

  describe "GET /api/v1/card_combinations/:card_id1/:card_id2" do
    context "with valid card IDs" do
      before do
        get "/api/v1/card_combinations/#{card1.id}/#{card2.id}", headers: auth_headers
      end

      it "returns HTTP status 200" do
        expect(response).to have_http_status(200)
      end

      it "returns a JSON response with the combination analysis" do
        expect(response.content_type).to include("application/json")
        expect(JSON.parse(response.body)).to have_key("combination_analysis")
        expect(JSON.parse(response.body)["combination_analysis"]).to eq("These cards together suggest a sudden opportunity for change.")
      end

      it "creates an instance of ReadingService with the current user" do
        expect(ReadingService).to have_received(:new).with(user: user)
      end

      it "calls analyze_card_combination with the correct card IDs" do
        expect(reading_service).to have_received(:analyze_card_combination).with(card1.id.to_s, card2.id.to_s)
      end
    end

    context "with invalid card IDs" do
      before do
        get "/api/v1/card_combinations/99999/88888", headers: auth_headers
      end

      it "returns HTTP status 404" do
        expect(response).to have_http_status(404)
      end

      it "returns an error message" do
        expect(JSON.parse(response.body)).to have_key("error")
        expect(JSON.parse(response.body)["error"]).to eq("One or both cards not found")
      end
    end

    context "when one card ID is valid and the other is invalid" do
      before do
        get "/api/v1/card_combinations/#{card1.id}/99999", headers: auth_headers
      end

      it "returns HTTP status 404" do
        expect(response).to have_http_status(404)
      end

      it "returns an error message" do
        expect(JSON.parse(response.body)).to have_key("error")
        expect(JSON.parse(response.body)["error"]).to eq("One or both cards not found")
      end
    end

    context "with different card combinations" do
      it "analyzes major and major arcana combinations" do
        get "/api/v1/card_combinations/#{card1.id}/#{card2.id}", headers: auth_headers
        expect(response).to have_http_status(200)
      end

      it "analyzes major and minor arcana combinations" do
        allow(reading_service).to receive(:analyze_card_combination).and_return("Major and minor arcana combination analysis")

        get "/api/v1/card_combinations/#{card1.id}/#{card3.id}", headers: auth_headers

        expect(response).to have_http_status(200)
        expect(JSON.parse(response.body)["combination_analysis"]).to eq("Major and minor arcana combination analysis")
      end
    end

    context "when user is not authenticated" do
      it "still works without authentication, using the first user" do
        # Expect ReadingService to be created with the first user
        expect(ReadingService).to receive(:new).with(user: User.first).and_return(reading_service)

        get "/api/v1/card_combinations/#{card1.id}/#{card2.id}"

        expect(response).to have_http_status(200)
      end
    end
  end

  describe "error handling" do
    context "when ReadingService raises an error" do
      before do
        allow(reading_service).to receive(:analyze_card_combination).and_raise(StandardError.new("Service error"))
      end

      it "returns HTTP status 422 and error message" do
        get "/api/v1/card_combinations/#{card1.id}/#{card2.id}", headers: auth_headers

        expect(response).to have_http_status(422)
        expect(JSON.parse(response.body)).to have_key("error")
      end
    end
  end
end
