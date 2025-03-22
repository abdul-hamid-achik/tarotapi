module Api
  module V1
    class HealthController < ApplicationController
      include AuthenticateRequest # Include the authentication concern
      
      # Detailed health check - authentication required
      def detailed
        # Authorize access - only admins should see detailed health
        authorize :health, :admin?
        
        db_ok = DatabaseHealthcheck.check_connection
        db_pool_ok = DatabaseHealthcheck.check_pool_health
        
        # Redis pool health check
        redis_ok = check_redis_health
        
        overall_status = db_ok && db_pool_ok && redis_ok ? 'ok' : 'degraded'
        
        # Get database pool stats
        db_pool_stats = begin
          pool = ActiveRecord::Base.connection_pool
          {
            size: pool.size,
            active: pool.connections.count(&:in_use?),
            idle: pool.connections.count { |c| !c.in_use? },
            waiting: pool.num_waiting_in_queue,
            usage_percent: ((pool.connections.count(&:in_use?).to_f / pool.size) * 100).round(1)
          }
        rescue => e
          { error: e.message }
        end
        
        # Get Redis pool stats
        redis_pool_stats = begin
          if defined?(RedisPool) && RedisPool.const_defined?(:CACHE_POOL)
            pool = RedisPool::CACHE_POOL
            {
              size: pool.size,
              available: pool.available,
              in_use: pool.size - pool.available,
              usage_percent: (((pool.size - pool.available).to_f / pool.size) * 100).round(1)
            }
          else
            { error: 'Redis pool not configured' }
          end
        rescue => e
          { error: e.message }
        end
        
        response = {
          status: overall_status,
          timestamp: Time.current,
          environment: Rails.env,
          components: {
            database: {
              status: db_ok ? 'ok' : 'error',
              pool_status: db_pool_ok ? 'ok' : 'warning',
              pool: db_pool_stats
            },
            redis: {
              status: redis_ok ? 'ok' : 'error',
              pool: redis_pool_stats
            }
          }
        }
        
        status_code = overall_status == 'ok' ? :ok : :service_unavailable
        render json: response, status: status_code
      end
      
      # Database-specific health check - authentication required
      def database
        # Authorize access - only admins should see detailed database health
        authorize :health, :admin?
        
        db_ok = DatabaseHealthcheck.check_connection
        db_pool_ok = DatabaseHealthcheck.check_pool_health
        
        status = db_ok ? (db_pool_ok ? 'ok' : 'warning') : 'error'
        
        # Get PostgreSQL database version and connection info
        db_info = begin
          result = ActiveRecord::Base.connection.execute("SELECT version();")
          { version: result.first['version'] }
        rescue => e
          { error: e.message }
        end
        
        # Get connection pool stats
        pool_stats = begin
          pool = ActiveRecord::Base.connection_pool
          {
            size: pool.size,
            active: pool.connections.count(&:in_use?),
            idle: pool.connections.count { |c| !c.in_use? },
            waiting: pool.num_waiting_in_queue,
            usage_percent: ((pool.connections.count(&:in_use?).to_f / pool.size) * 100).round(1)
          }
        rescue => e
          { error: e.message }
        end
        
        response = {
          status: status,
          timestamp: Time.current,
          database: db_info,
          pool: pool_stats
        }
        
        status_code = status == 'ok' ? :ok : (status == 'warning' ? :ok : :service_unavailable)
        render json: response, status: status_code
      end
      
      private
      
      def check_redis_health
        return false unless defined?(RedisPool) && RedisPool.respond_to?(:with_redis)
        
        begin
          RedisPool.with_redis do |redis|
            # Simple ping test
            result = redis.ping
            result == "PONG"
          end
        rescue => e
          Rails.logger.error "Redis health check failed ⚠️: #{e.message}"
          false
        end
      end
    end
  end
end 