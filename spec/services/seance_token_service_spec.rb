require 'rails_helper'

RSpec.describe SeanceTokenService do
  let(:client_id) { SecureRandom.uuid }
  let(:service) { described_class.new }

  describe '#generate_token' do
    it 'generates a token for a client_id' do
      token_data = service.generate_token(client_id)

      expect(token_data[:token]).to be_present
      expect(token_data[:expires_at]).to be > Time.current
    end

    it 'returns the same token for the same client_id within expiration' do
      first_token = service.generate_token(client_id)
      second_token = service.generate_token(client_id)

      expect(second_token[:token]).to eq(first_token[:token])
      first_date = Time.parse(first_token[:expires_at].to_s)
      second_date = Time.parse(second_token[:expires_at].to_s)
      expect(second_date).to be_within(1.second).of(first_date)
    end

    it 'generates a new token when previous token expires' do
      first_token = service.generate_token(client_id)

      # simulate token expiration
      allow(Time).to receive(:current).and_return(first_token[:expires_at] + 1.minute)

      second_token = service.generate_token(client_id)
      expect(second_token[:token]).not_to eq(first_token[:token])
    end
  end

  describe '#validate_token' do
    let(:token_data) { service.generate_token(client_id) }
    let(:token) { token_data[:token] }

    it 'validates a valid token' do
      result = service.validate_token(token)

      expect(result[:valid]).to be true
      expect(result[:client_id]).to eq(client_id)
    end

    it 'invalidates an expired token' do
      allow(Time).to receive(:current).and_return(token_data[:expires_at] + 1.minute)

      result = service.validate_token(token)
      expect(result[:valid]).to be false
      expect(result[:error]).to include('token expired')
    end

    it 'invalidates a malformed token' do
      result = service.validate_token('invalid_token')

      expect(result[:valid]).to be false
      expect(result[:error]).to include('invalid token format')
    end
  end

  describe '#clear_expired_tokens' do
    it 'removes expired tokens from storage' do
      token_data = service.generate_token(client_id)

      allow(Time).to receive(:current).and_return(token_data[:expires_at] + 1.minute)
      service.clear_expired_tokens

      result = service.validate_token(token_data[:token])
      expect(result[:valid]).to be false
    end
  end
end
