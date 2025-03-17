require 'rails_helper'

RSpec.describe 'rate limiting', type: :request do
  let(:client_id) { SecureRandom.uuid }

  before do
    # clear any rate limit counters before each test
    Redis.new(url: ENV['REDIS_URL']).flushdb
  end

  describe 'seance endpoint rate limiting' do
    it 'allows requests within rate limit' do
      29.times do
        post '/api/v1/seance', params: { client_id: client_id }
        expect(response).to have_http_status(:created)
      end
    end

    it 'blocks requests over rate limit' do
      31.times do |i|
        post '/api/v1/seance', params: { client_id: client_id }
        
        if i >= 30
          expect(response).to have_http_status(429)
          expect(json_response['error']).to include('rate limit exceeded')
          expect(response.headers['x-ratelimit-limit']).to be_present
          expect(response.headers['x-ratelimit-remaining']).to be_present
          expect(response.headers['x-ratelimit-reset']).to be_present
        end
      end
    end
  end

  describe 'reading sessions endpoint rate limiting' do
    let(:spread) { create(:spread) }

    it 'allows requests within rate limit' do
      59.times do
        post '/api/v1/reading_sessions', params: { spread_id: spread.id }
        expect(response).not_to have_http_status(429)
      end
    end

    it 'blocks requests over rate limit' do
      61.times do |i|
        post '/api/v1/reading_sessions', params: { spread_id: spread.id }
        
        if i >= 60
          expect(response).to have_http_status(429)
          expect(json_response['error']).to include('rate limit exceeded')
        end
      end
    end
  end

  describe 'general api rate limiting' do
    it 'allows requests within rate limit' do
      299.times do
        get '/api/v1/spreads'
        expect(response).not_to have_http_status(429)
      end
    end

    it 'blocks requests over rate limit' do
      301.times do |i|
        get '/api/v1/spreads'
        
        if i >= 300
          expect(response).to have_http_status(429)
          expect(json_response['error']).to include('rate limit exceeded')
        end
      end
    end
  end

  private

  def json_response
    JSON.parse(response.body)
  end
end 