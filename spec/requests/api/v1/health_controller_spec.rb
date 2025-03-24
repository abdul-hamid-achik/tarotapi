require 'rails_helper'

RSpec.describe Api::V1::HealthController, type: :request do
  let(:admin_user) { create(:user, role: 'admin') }
  let(:regular_user) { create(:user, role: 'user') }
  let(:admin_auth_header) { { 'Authorization' => "Bearer #{admin_token}" } }
  let(:user_auth_header) { { 'Authorization' => "Bearer #{user_token}" } }
  let(:admin_token) { 'admin_token' }
  let(:user_token) { 'user_token' }

  before do
    # Mock JWT authentication
    allow_any_instance_of(AuthenticateRequest).to receive(:authenticate_request).and_return(true)
    allow_any_instance_of(AuthenticateRequest).to receive(:current_user).and_return(regular_user)
    # Allow admins through for admin tests
    allow_any_instance_of(Api::V1::HealthController).to receive(:current_user).and_return(regular_user)
  end

  describe 'GET /api/v1/health/detailed' do
    context 'when user is admin' do
      before do
        allow_any_instance_of(Api::V1::HealthController).to receive(:current_user).and_return(admin_user)
        allow_any_instance_of(Api::V1::HealthController).to receive(:authorize).with(:health, :admin?).and_return(true)

        # Mock database checks
        allow(DatabaseHealthcheck).to receive(:check_connection).and_return(true)
        allow(DatabaseHealthcheck).to receive(:check_pool_health).and_return(true)

        # Mock Redis checks
        allow_any_instance_of(Api::V1::HealthController).to receive(:check_redis_health).and_return(true)

        # Mock ActiveRecord connection pool
        mock_pool = double(
          size: 5,
          connections: [ double(in_use?: true), double(in_use?: true), double(in_use?: false) ],
          num_waiting_in_queue: 0
        )
        allow(ActiveRecord::Base).to receive(:connection_pool).and_return(mock_pool)

        # Mock Redis pool if defined
        if defined?(RedisPool) && RedisPool.const_defined?(:CACHE_POOL)
          mock_redis_pool = double(size: 10, available: 8)
          allow(RedisPool::CACHE_POOL).to receive(:size).and_return(10)
          allow(RedisPool::CACHE_POOL).to receive(:available).and_return(8)
        end
      end

      it 'returns detailed health status with 200 OK when all systems are healthy' do
        get '/api/v1/health/detailed', headers: admin_auth_header

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)

        expect(body['status']).to eq('ok')
        expect(body['components']['database']['status']).to eq('ok')
        expect(body['components']['database']['pool_status']).to eq('ok')
        expect(body['components']['redis']['status']).to eq('ok')
      end

      it 'returns degraded status with 503 when database is unhealthy' do
        allow(DatabaseHealthcheck).to receive(:check_connection).and_return(false)

        get '/api/v1/health/detailed', headers: admin_auth_header

        expect(response).to have_http_status(:service_unavailable)
        body = JSON.parse(response.body)

        expect(body['status']).to eq('degraded')
        expect(body['components']['database']['status']).to eq('error')
      end

      it 'returns degraded status with 503 when redis is unhealthy' do
        allow_any_instance_of(Api::V1::HealthController).to receive(:check_redis_health).and_return(false)

        get '/api/v1/health/detailed', headers: admin_auth_header

        expect(response).to have_http_status(:service_unavailable)
        body = JSON.parse(response.body)

        expect(body['status']).to eq('degraded')
        expect(body['components']['redis']['status']).to eq('error')
      end
    end

    context 'when user is not admin' do
      before do
        allow_any_instance_of(Api::V1::HealthController).to receive(:authorize).with(:health, :admin?).and_raise(Pundit::NotAuthorizedError)
      end

      it 'returns 403 Forbidden' do
        get '/api/v1/health/detailed', headers: user_auth_header

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'GET /api/v1/health/database' do
    context 'when user is admin' do
      before do
        allow_any_instance_of(Api::V1::HealthController).to receive(:current_user).and_return(admin_user)
        allow_any_instance_of(Api::V1::HealthController).to receive(:authorize).with(:health, :admin?).and_return(true)

        # Mock database checks
        allow(DatabaseHealthcheck).to receive(:check_connection).and_return(true)
        allow(DatabaseHealthcheck).to receive(:check_pool_health).and_return(true)

        # Mock ActiveRecord connection
        mock_pg_result = [ { 'version' => 'PostgreSQL 14.5' } ]
        mock_result = double(first: { 'version' => 'PostgreSQL 14.5' })
        allow(ActiveRecord::Base).to receive_message_chain(:connection, :execute).with('SELECT version();').and_return(mock_result)

        # Mock ActiveRecord connection pool
        mock_pool = double(
          size: 5,
          connections: [ double(in_use?: true), double(in_use?: true), double(in_use?: false) ],
          num_waiting_in_queue: 0
        )
        allow(ActiveRecord::Base).to receive(:connection_pool).and_return(mock_pool)
      end

      it 'returns database health status with 200 OK when database is healthy' do
        get '/api/v1/health/database', headers: admin_auth_header

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)

        expect(body['status']).to eq('ok')
        expect(body['database']).to have_key('version')
        expect(body['pool']).to have_key('size')
        expect(body['pool']).to have_key('active')
        expect(body['pool']).to have_key('idle')
      end

      it 'returns warning status with 200 OK when database connection is good but pool has issues' do
        allow(DatabaseHealthcheck).to receive(:check_pool_health).and_return(false)

        get '/api/v1/health/database', headers: admin_auth_header

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)

        expect(body['status']).to eq('warning')
      end

      it 'returns error status with 503 when database connection fails' do
        allow(DatabaseHealthcheck).to receive(:check_connection).and_return(false)

        get '/api/v1/health/database', headers: admin_auth_header

        expect(response).to have_http_status(:service_unavailable)
        body = JSON.parse(response.body)

        expect(body['status']).to eq('error')
      end
    end

    context 'when user is not admin' do
      before do
        allow_any_instance_of(Api::V1::HealthController).to receive(:authorize).with(:health, :admin?).and_raise(Pundit::NotAuthorizedError)
      end

      it 'returns 403 Forbidden' do
        get '/api/v1/health/database', headers: user_auth_header

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe '#check_redis_health' do
    context 'when RedisPool is defined' do
      before do
        # Only for this test - define RedisPool if not defined
        unless defined?(RedisPool)
          class_eval do
            class RedisPool
              def self.with_redis
                yield double(ping: 'PONG')
              end
            end
          end
        end

        allow(RedisPool).to receive(:respond_to?).with(:with_redis).and_return(true)
      end

      it 'returns true when redis ping returns PONG' do
        mock_redis = double('Redis')
        allow(mock_redis).to receive(:ping).and_return('PONG')
        allow(RedisPool).to receive(:with_redis).and_yield(mock_redis)

        controller = Api::V1::HealthController.new
        expect(controller.send(:check_redis_health)).to eq(true)
      end

      it 'returns false when redis ping fails' do
        allow(RedisPool).to receive(:with_redis).and_raise(Redis::CannotConnectError.new("connection error"))
        allow(Rails.logger).to receive(:error)

        controller = Api::V1::HealthController.new
        expect(controller.send(:check_redis_health)).to eq(false)
        expect(Rails.logger).to have_received(:error).with(/Redis health check failed/)
      end
    end

    context 'when RedisPool is not defined' do
      before do
        # Temporarily remove RedisPool if defined
        if defined?(RedisPool)
          @original_redis_pool = RedisPool
          Object.send(:remove_const, :RedisPool)
        end
      end

      after do
        # Restore RedisPool if it was defined
        if instance_variable_defined?('@original_redis_pool')
          RedisPool = @original_redis_pool
        end
      end

      it 'returns false' do
        controller = Api::V1::HealthController.new
        expect(controller.send(:check_redis_health)).to eq(false)
      end
    end
  end
end
