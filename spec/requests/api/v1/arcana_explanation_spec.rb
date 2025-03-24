require 'rails_helper'

RSpec.describe "API V1 Arcana Explanation", type: :request do
  let!(:user) { create(:user) }
  let!(:auth_headers) { user.create_new_auth_token }
  let!(:reading) { create(:reading, user: user) }
  let(:reading_service) { instance_double(ReadingService) }

  before do
    allow(ReadingService).to receive(:new).and_return(reading_service)
    # Allow the authorize method to pass
    allow_any_instance_of(Api::V1::ReadingsController).to receive(:authorize).and_return(true)
  end

  describe "GET /api/v1/arcana/:arcana_type" do
    context "with major arcana type" do
      before do
        allow(reading_service).to receive(:get_arcana_explanation)
          .with("major", nil)
          .and_return("Major Arcana represents powerful forces and significant life events.")

        get "/api/v1/arcana/major", headers: auth_headers
      end

      it "returns HTTP status 200" do
        expect(response).to have_http_status(200)
      end

      it "returns a JSON response with the arcana explanation" do
        expect(response.content_type).to include("application/json")
        expect(JSON.parse(response.body)).to have_key("arcana_explanation")
        expect(JSON.parse(response.body)["arcana_explanation"]).to eq("Major Arcana represents powerful forces and significant life events.")
      end

      it "creates an instance of ReadingService with the current user" do
        expect(ReadingService).to have_received(:new).with(user: user)
      end

      it "calls get_arcana_explanation with the correct arcana type" do
        expect(reading_service).to have_received(:get_arcana_explanation).with("major", nil)
      end
    end

    context "with minor arcana type" do
      before do
        allow(reading_service).to receive(:get_arcana_explanation)
          .with("minor", nil)
          .and_return("Minor Arcana relates to everyday situations and challenges.")

        get "/api/v1/arcana/minor", headers: auth_headers
      end

      it "returns HTTP status 200" do
        expect(response).to have_http_status(200)
      end

      it "returns the minor arcana explanation" do
        expect(JSON.parse(response.body)["arcana_explanation"]).to eq("Minor Arcana relates to everyday situations and challenges.")
      end
    end

    context "with invalid arcana type" do
      before do
        get "/api/v1/arcana/invalid", headers: auth_headers
      end

      it "returns HTTP status 422" do
        expect(response).to have_http_status(422)
      end

      it "returns an error message" do
        expect(JSON.parse(response.body)).to have_key("errors")
        expect(JSON.parse(response.body)["errors"][0]["detail"]).to eq("invalid arcana type. must be 'major' or 'minor'")
      end
    end
  end

  describe "GET /api/v1/arcana/:arcana_type/:specific_card" do
    context "with specific major arcana card" do
      before do
        allow(reading_service).to receive(:get_arcana_explanation)
          .with("major", "fool")
          .and_return("The Fool represents new beginnings and unlimited potential.")

        get "/api/v1/arcana/major/fool", headers: auth_headers
      end

      it "returns HTTP status 200" do
        expect(response).to have_http_status(200)
      end

      it "returns the specific card explanation" do
        expect(JSON.parse(response.body)["arcana_explanation"]).to eq("The Fool represents new beginnings and unlimited potential.")
      end

      it "calls get_arcana_explanation with the correct parameters" do
        expect(reading_service).to have_received(:get_arcana_explanation).with("major", "fool")
      end
    end

    context "with specific minor arcana card" do
      before do
        allow(reading_service).to receive(:get_arcana_explanation)
          .with("minor", "cups")
          .and_return("Cups represent emotions, relationships, and creativity.")

        get "/api/v1/arcana/minor/cups", headers: auth_headers
      end

      it "returns the specific suit explanation" do
        expect(JSON.parse(response.body)["arcana_explanation"]).to eq("Cups represent emotions, relationships, and creativity.")
      end
    end
  end

  describe "authorization" do
    context "when user is not authenticated" do
      it "returns unauthorized status" do
        get "/api/v1/arcana/major"

        expect(response).to have_http_status(401)
      end
    end

    context "when authorization fails" do
      before do
        allow_any_instance_of(Api::V1::ReadingsController).to receive(:authorize).and_raise(Pundit::NotAuthorizedError)
      end

      it "returns forbidden status" do
        get "/api/v1/arcana/major", headers: auth_headers

        expect(response).to have_http_status(403)
      end
    end
  end

  describe "error handling" do
    context "when ReadingService raises an error" do
      before do
        allow(reading_service).to receive(:get_arcana_explanation).and_raise(StandardError.new("Service error"))
        get "/api/v1/arcana/major", headers: auth_headers
      end

      it "returns HTTP status 500" do
        expect(response).to have_http_status(500)
      end

      it "returns an error message" do
        expect(JSON.parse(response.body)).to have_key("error")
      end
    end
  end
end
