class DatabaseHealthcheck
  class << self
    # Check database connection health and restore if necessary
    def check_connection
      begin
        # Try to execute a simple query to test the connection
        result = ActiveRecord::Base.connection.execute("SELECT 1 AS health_check")
        
        # If successful, connection is healthy
        if result.first["health_check"] == 1
          Rails.logger.debug "Database connection is healthy" if Rails.env.development?
          return true
        else
          Rails.logger.warn "Database connection returned unexpected result ⚠️"
          reconnect
          return false
        end
      rescue => e
        Rails.logger.error "Database connection error detected ⚠️: #{e.message}"
        reconnect
        return false
      end
    end
    
    # Verify connection pool health
    def check_pool_health
      begin
        pool = ActiveRecord::Base.connection_pool
        
        # Get pool statistics
        stats = {
          size: pool.size, 
          active: pool.connections.count(&:in_use?),
          idle: pool.connections.count { |c| !c.in_use? },
          waiting: pool.num_waiting_in_queue
        }
        
        # Check for potential issues
        issues = []
        issues << "high usage (#{stats[:active]}/#{stats[:size]})" if stats[:active] > (stats[:size] * 0.8)
        issues << "waiting connections (#{stats[:waiting]})" if stats[:waiting] > 0
        
        if issues.any?
          Rails.logger.warn "Connection pool health issues detected ⚠️: #{issues.join(', ')}"
          
          # If we have too many connections, try to recover
          if stats[:active] >= stats[:size]
            Rails.logger.warn "Connection pool saturated ⚠️ - attempting recovery"
            reap_connections
          end
          
          return false
        end
        
        Rails.logger.debug "Connection pool is healthy: #{stats.inspect}" if Rails.env.development?
        true
      rescue => e
        Rails.logger.error "Error checking connection pool health ⚠️: #{e.message}"
        false
      end
    end
    
    # Verify all connections in the pool
    def verify_all_connections
      begin
        pool = ActiveRecord::Base.connection_pool
        initial_count = pool.connections.length
        
        # This will verify all connections and remove bad ones
        removed = pool.connections.reject do |conn|
          begin
            conn.verify!
          rescue => e
            Rails.logger.warn "Removing bad connection from pool ⚠️: #{e.message}"
            false
          end
        end.count
        
        # Log result
        if removed > 0
          Rails.logger.info "Removed #{removed} bad connections from pool, #{pool.connections.length}/#{pool.size} remaining"
        else
          Rails.logger.debug "All #{initial_count} connections verified successfully" if Rails.env.development?
        end
        
        removed == 0
      rescue => e
        Rails.logger.error "Error verifying connections ⚠️: #{e.message}"
        false
      end
    end
    
    private
    
    # Reconnect to the database
    def reconnect
      begin
        # Clear active connections first
        ActiveRecord::Base.clear_active_connections!
        
        # Try to reconnect
        ActiveRecord::Base.connection.reconnect!
        Rails.logger.info "Successfully reconnected to database"
      rescue => e
        Rails.logger.error "Failed to reconnect to database ⚠️: #{e.message}"
      end
    end
    
    # Reap connections to recover from pool saturation
    def reap_connections
      begin
        # First try normal reaping
        ActiveRecord::Base.connection_pool.reap
        
        # If that's not enough, clear all connections
        if ActiveRecord::Base.connection_pool.connections.count(&:in_use?) >= (ActiveRecord::Base.connection_pool.size * 0.8)
          Rails.logger.warn "Aggressively clearing connection pool ⚠️"
          ActiveRecord::Base.connection_pool.disconnect!
        end
        
        Rails.logger.info "Connection pool cleaned up"
      rescue => e
        Rails.logger.error "Failed to reap connections ⚠️: #{e.message}"
      end
    end
  end
end 