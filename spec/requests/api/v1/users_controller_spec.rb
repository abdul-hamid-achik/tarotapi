require 'rails_helper'

RSpec.describe "Api::V1::Users", type: :request do
  let(:user) { create(:user) }
  let(:admin_user) { create(:user, role: 'admin') }
  let(:headers) { { 'Accept' => 'application/json' } }
  let(:auth_headers) {
    headers.merge({ 'Authorization' => "Bearer #{generate_token_for(user)}" })
  }
  let(:admin_auth_headers) {
    headers.merge({ 'Authorization' => "Bearer #{generate_token_for(admin_user)}" })
  }

  # Helper method to generate a JWT token for a user
  def generate_token_for(user)
    payload = { sub: user.id, exp: 24.hours.from_now.to_i }
    JWT.encode(payload, Rails.application.credentials.secret_key_base)
  end

  describe "GET /api/v1/users/:id" do
    context "when authenticated" do
      it "returns the user's own profile" do
        get "/api/v1/users/#{user.id}", headers: auth_headers

        expect(response).to have_http_status(:success)
        expect(JSON.parse(response.body)).to include('id' => user.id)
      end

      it "returns 403 when accessing another user's profile" do
        another_user = create(:user)

        get "/api/v1/users/#{another_user.id}", headers: auth_headers

        expect(response).to have_http_status(:forbidden)
      end

      it "allows admin to access any user profile" do
        get "/api/v1/users/#{user.id}", headers: admin_auth_headers

        expect(response).to have_http_status(:success)
        expect(JSON.parse(response.body)).to include('id' => user.id)
      end

      it "returns 404 for non-existent user" do
        get "/api/v1/users/999999", headers: auth_headers

        expect(response).to have_http_status(:not_found)
      end
    end

    context "when not authenticated" do
      it "returns 401 unauthorized" do
        get "/api/v1/users/#{user.id}", headers: headers

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "POST /api/v1/users" do
    let(:valid_attributes) {
      {
        user: {
          email: "newuser@example.com",
          password: "password123",
          password_confirmation: "password123",
          name: "New User",
          time_zone: "Eastern Time (US & Canada)"
        }
      }
    }

    let(:invalid_attributes) {
      {
        user: {
          email: "invalid-email",
          password: "short",
          password_confirmation: "mismatch"
        }
      }
    }

    it "creates a new user with valid attributes" do
      expect {
        post "/api/v1/users", params: valid_attributes, headers: headers
      }.to change(User, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)).to include('id', 'email')
      expect(JSON.parse(response.body)['email']).to eq('newuser@example.com')
    end

    it "returns 422 with validation errors for invalid attributes" do
      expect {
        post "/api/v1/users", params: invalid_attributes, headers: headers
      }.not_to change(User, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)).to include('error')
    end

    it "returns 409 when email is already taken" do
      existing_user = create(:user, email: "existing@example.com")

      post "/api/v1/users",
        params: { user: { email: "existing@example.com", password: "password123" } },
        headers: headers

      expect(response).to have_http_status(:conflict)
      expect(JSON.parse(response.body)).to include('error')
    end
  end

  describe "PATCH /api/v1/users/:id" do
    let(:valid_update_attributes) {
      {
        user: {
          name: "Updated Name",
          time_zone: "Pacific Time (US & Canada)"
        }
      }
    }

    context "when authenticated" do
      it "updates the user's own profile" do
        patch "/api/v1/users/#{user.id}",
          params: valid_update_attributes,
          headers: auth_headers

        expect(response).to have_http_status(:success)
        expect(JSON.parse(response.body)['name']).to eq('Updated Name')
        expect(user.reload.name).to eq('Updated Name')
      end

      it "returns 403 when updating another user's profile" do
        another_user = create(:user)

        patch "/api/v1/users/#{another_user.id}",
          params: valid_update_attributes,
          headers: auth_headers

        expect(response).to have_http_status(:forbidden)
      end

      it "allows admin to update any user profile" do
        patch "/api/v1/users/#{user.id}",
          params: valid_update_attributes,
          headers: admin_auth_headers

        expect(response).to have_http_status(:success)
        expect(JSON.parse(response.body)['name']).to eq('Updated Name')
        expect(user.reload.name).to eq('Updated Name')
      end

      it "returns 422 with validation errors for invalid updates" do
        patch "/api/v1/users/#{user.id}",
          params: { user: { email: "invalid-email" } },
          headers: auth_headers

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "when not authenticated" do
      it "returns 401 unauthorized" do
        patch "/api/v1/users/#{user.id}",
          params: valid_update_attributes,
          headers: headers

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "DELETE /api/v1/users/:id" do
    context "when authenticated" do
      it "allows a user to delete their own account" do
        delete "/api/v1/users/#{user.id}", headers: auth_headers

        expect(response).to have_http_status(:no_content)
        expect(User.find_by(id: user.id)).to be_nil
      end

      it "returns 403 when deleting another user's account" do
        another_user = create(:user)

        delete "/api/v1/users/#{another_user.id}", headers: auth_headers

        expect(response).to have_http_status(:forbidden)
        expect(User.find_by(id: another_user.id)).not_to be_nil
      end

      it "allows admin to delete any user account" do
        delete "/api/v1/users/#{user.id}", headers: admin_auth_headers

        expect(response).to have_http_status(:no_content)
        expect(User.find_by(id: user.id)).to be_nil
      end
    end

    context "when not authenticated" do
      it "returns 401 unauthorized" do
        delete "/api/v1/users/#{user.id}", headers: headers

        expect(response).to have_http_status(:unauthorized)
        expect(User.find_by(id: user.id)).not_to be_nil
      end
    end
  end
end
