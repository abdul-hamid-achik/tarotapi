require 'rails_helper'

RSpec.describe Api::V1::OrganizationsController, type: :request do
  let(:user) { create(:user) }
  let(:admin_user) { create(:user) }
  let(:organization) { create(:organization) }
  let(:auth_headers) { { 'Authorization' => "Bearer #{token}" } }
  let(:token) { 'valid_token' }

  before do
    # Mock authentication
    allow_any_instance_of(AuthenticateRequest).to receive(:authenticate_request).and_return(true)
    allow_any_instance_of(AuthenticateRequest).to receive(:current_user).and_return(user)
  end

  describe 'GET /api/v1/organizations' do
    let!(:org1) { create(:organization) }
    let!(:org2) { create(:organization) }
    let!(:membership) { create(:membership, user: user, organization: org1) }

    it 'returns organizations the user is a member of' do
      # Mock policy scope
      allow_any_instance_of(OrganizationPolicy::Scope).to receive(:resolve).and_return([ org1 ])

      get '/api/v1/organizations', headers: auth_headers

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body.size).to eq(1)
      expect(body.first['id']).to eq(org1.id)
    end
  end

  describe 'GET /api/v1/organizations/:id' do
    context 'when user is a member' do
      before do
        create(:membership, user: user, organization: organization)
        allow_any_instance_of(OrganizationPolicy).to receive(:show?).and_return(true)
      end

      it 'returns the organization' do
        get "/api/v1/organizations/#{organization.id}", headers: auth_headers

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body['id']).to eq(organization.id)
        expect(body['name']).to eq(organization.name)
      end
    end

    context 'when user is not a member' do
      before do
        allow_any_instance_of(OrganizationPolicy).to receive(:show?).and_raise(Pundit::NotAuthorizedError)
      end

      it 'returns 403 forbidden' do
        get "/api/v1/organizations/#{organization.id}", headers: auth_headers

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'POST /api/v1/organizations' do
    let(:valid_params) do
      {
        organization: {
          name: 'New Organization',
          plan: 'basic',
          billing_email: 'billing@example.com',
          settings: { white_label: true }
        }
      }
    end

    context 'when request is valid' do
      before do
        allow_any_instance_of(OrganizationPolicy).to receive(:create?).and_return(true)
      end

      it 'creates a new organization' do
        expect {
          post '/api/v1/organizations', params: valid_params, headers: auth_headers
        }.to change(Organization, :count).by(1)

        expect(response).to have_http_status(:created)
        body = JSON.parse(response.body)
        expect(body['name']).to eq('New Organization')

        # Check that membership was created
        organization = Organization.find(body['id'])
        expect(organization.memberships.count).to eq(1)
        expect(organization.memberships.first.user).to eq(user)
        expect(organization.memberships.first.role).to eq('admin')
      end
    end

    context 'when request is invalid' do
      let(:invalid_params) { { organization: { name: '' } } }

      before do
        allow_any_instance_of(OrganizationPolicy).to receive(:create?).and_return(true)
      end

      it 'returns unprocessable entity status' do
        post '/api/v1/organizations', params: invalid_params, headers: auth_headers

        expect(response).to have_http_status(:unprocessable_entity)
        body = JSON.parse(response.body)
        expect(body).to have_key('errors')
      end
    end

    context 'when user is not authorized' do
      before do
        allow_any_instance_of(OrganizationPolicy).to receive(:create?).and_raise(Pundit::NotAuthorizedError)
      end

      it 'returns 403 forbidden' do
        post '/api/v1/organizations', params: valid_params, headers: auth_headers

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'PATCH /api/v1/organizations/:id' do
    let(:update_params) do
      {
        organization: {
          name: 'Updated Organization',
          billing_email: 'updated@example.com'
        }
      }
    end

    context 'when user is admin' do
      before do
        create(:membership, user: user, organization: organization, role: 'admin')
        allow_any_instance_of(OrganizationPolicy).to receive(:update?).and_return(true)
      end

      it 'updates the organization' do
        patch "/api/v1/organizations/#{organization.id}", params: update_params, headers: auth_headers

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body['name']).to eq('Updated Organization')
        expect(body['billing_email']).to eq('updated@example.com')
      end
    end

    context 'when user is not authorized' do
      before do
        allow_any_instance_of(OrganizationPolicy).to receive(:update?).and_raise(Pundit::NotAuthorizedError)
      end

      it 'returns 403 forbidden' do
        patch "/api/v1/organizations/#{organization.id}", params: update_params, headers: auth_headers

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'DELETE /api/v1/organizations/:id' do
    context 'when user is admin' do
      before do
        create(:membership, user: user, organization: organization, role: 'admin')
        allow_any_instance_of(OrganizationPolicy).to receive(:destroy?).and_return(true)
      end

      it 'deletes the organization' do
        expect {
          delete "/api/v1/organizations/#{organization.id}", headers: auth_headers
        }.to change(Organization, :count).by(-1)

        expect(response).to have_http_status(:no_content)
      end
    end

    context 'when user is not authorized' do
      before do
        allow_any_instance_of(OrganizationPolicy).to receive(:destroy?).and_raise(Pundit::NotAuthorizedError)
      end

      it 'returns 403 forbidden' do
        delete "/api/v1/organizations/#{organization.id}", headers: auth_headers

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'POST /api/v1/organizations/:id/members' do
    let(:new_user_email) { 'newuser@example.com' }
    let(:member_params) do
      {
        membership: {
          email: new_user_email,
          role: 'member',
          name: 'New User'
        }
      }
    end

    context 'when user is admin' do
      before do
        create(:membership, user: user, organization: organization, role: 'admin')
        allow_any_instance_of(OrganizationPolicy).to receive(:manage_members?).and_return(true)
        allow(OrganizationMailer).to receive_message_chain(:invitation_email, :deliver_later)
      end

      it 'adds a new member to the organization' do
        expect {
          post "/api/v1/organizations/#{organization.id}/members", params: member_params, headers: auth_headers
        }.to change(Membership, :count).by(1)

        expect(response).to have_http_status(:created)
        membership = Membership.last
        expect(membership.email).to eq(new_user_email)
        expect(membership.role).to eq('member')
      end

      it 'sends an invitation email' do
        post "/api/v1/organizations/#{organization.id}/members", params: member_params, headers: auth_headers

        expect(OrganizationMailer).to have_received(:invitation_email)
      end
    end

    context 'when user is not authorized' do
      before do
        allow_any_instance_of(OrganizationPolicy).to receive(:manage_members?).and_raise(Pundit::NotAuthorizedError)
      end

      it 'returns 403 forbidden' do
        post "/api/v1/organizations/#{organization.id}/members", params: member_params, headers: auth_headers

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'DELETE /api/v1/organizations/:id/members/:user_id' do
    let(:member) { create(:user) }
    let!(:membership) { create(:membership, user: member, organization: organization) }

    context 'when user is admin' do
      before do
        create(:membership, user: user, organization: organization, role: 'admin')
        allow_any_instance_of(OrganizationPolicy).to receive(:manage_members?).and_return(true)
      end

      it 'removes the member from the organization' do
        expect {
          delete "/api/v1/organizations/#{organization.id}/members/#{member.id}", headers: auth_headers
        }.to change(Membership, :count).by(-1)

        expect(response).to have_http_status(:no_content)
      end
    end

    context 'when user is not authorized' do
      before do
        allow_any_instance_of(OrganizationPolicy).to receive(:manage_members?).and_raise(Pundit::NotAuthorizedError)
      end

      it 'returns 403 forbidden' do
        delete "/api/v1/organizations/#{organization.id}/members/#{member.id}", headers: auth_headers

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'GET /api/v1/organizations/:id/usage' do
    let(:usage_data) do
      {
        readings: { total: 100, daily: [ 10, 15, 20 ] },
        api_calls: { total: 500, daily: [ 50, 75, 100 ] }
      }
    end

    context 'when user is authorized' do
      before do
        create(:membership, user: user, organization: organization)
        allow_any_instance_of(OrganizationPolicy).to receive(:view_usage?).and_return(true)
        allow_any_instance_of(Organization).to receive(:usage_metrics).and_return(usage_data)
      end

      it 'returns usage metrics' do
        get "/api/v1/organizations/#{organization.id}/usage", headers: auth_headers

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body['readings']['total']).to eq(100)
        expect(body['api_calls']['total']).to eq(500)
      end

      it 'passes query parameters to usage_metrics method' do
        get "/api/v1/organizations/#{organization.id}/usage", params: { start_date: '2023-01-01', end_date: '2023-01-31', granularity: 'monthly' }, headers: auth_headers

        expect(organization).to have_received(:usage_metrics).with(
          start_date: Date.new(2023, 1, 1),
          end_date: Date.new(2023, 1, 31),
          granularity: :monthly
        )
      end
    end

    context 'when user is not authorized' do
      before do
        allow_any_instance_of(OrganizationPolicy).to receive(:view_usage?).and_raise(Pundit::NotAuthorizedError)
      end

      it 'returns 403 forbidden' do
        get "/api/v1/organizations/#{organization.id}/usage", headers: auth_headers

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'GET /api/v1/organizations/:id/analytics' do
    let(:analytics_data) do
      {
        user_growth: [ 10, 15, 20 ],
        reading_trends: { total: 500, by_spread: { 'Celtic Cross': 200, 'Three Card': 300 } }
      }
    end

    context 'when user is authorized' do
      before do
        create(:membership, user: user, organization: organization, role: 'admin')
        allow_any_instance_of(OrganizationPolicy).to receive(:view_analytics?).and_return(true)
        allow_any_instance_of(Organization).to receive(:analytics).and_return(analytics_data)
      end

      it 'returns analytics data' do
        get "/api/v1/organizations/#{organization.id}/analytics", headers: auth_headers

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body['user_growth']).to eq([ 10, 15, 20 ])
        expect(body['reading_trends']['total']).to eq(500)
      end

      it 'passes query parameters to analytics method' do
        get "/api/v1/organizations/#{organization.id}/analytics", params: { start_date: '2023-01-01', end_date: '2023-01-31', metrics: 'user_growth,reading_trends' }, headers: auth_headers

        expect(organization).to have_received(:analytics).with(
          start_date: Date.new(2023, 1, 1),
          end_date: Date.new(2023, 1, 31),
          metrics: 'user_growth,reading_trends'
        )
      end
    end

    context 'when user is not authorized' do
      before do
        allow_any_instance_of(OrganizationPolicy).to receive(:view_analytics?).and_raise(Pundit::NotAuthorizedError)
      end

      it 'returns 403 forbidden' do
        get "/api/v1/organizations/#{organization.id}/analytics", headers: auth_headers

        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
