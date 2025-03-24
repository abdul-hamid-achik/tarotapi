require 'rails_helper'

RSpec.describe DatabaseHealthcheck do
  describe '.check_connection' do
    let(:mock_connection) { double("Connection") }
    let(:mock_result) { [ { "health_check" => 1 } ] }

    before do
      allow(ActiveRecord::Base).to receive(:connection).and_return(mock_connection)
      allow(Rails.logger).to receive(:debug)
      allow(Rails.logger).to receive(:warn)
      allow(Rails.logger).to receive(:error)
      allow(Rails.logger).to receive(:info)
      allow(DatabaseHealthcheck).to receive(:reconnect)
    end

    context 'when connection is healthy' do
      it 'returns true if query succeeds' do
        expect(mock_connection).to receive(:execute).with("SELECT 1 AS health_check").and_return(mock_result)

        expect(DatabaseHealthcheck.check_connection).to be true
        expect(Rails.logger).to have_received(:debug).with("Database connection is healthy") if Rails.env.development?
      end
    end

    context 'when connection query returns unexpected result' do
      let(:mock_result) { [ { "health_check" => 0 } ] }

      it 'reconnects and returns false' do
        expect(mock_connection).to receive(:execute).with("SELECT 1 AS health_check").and_return(mock_result)

        expect(DatabaseHealthcheck.check_connection).to be false
        expect(Rails.logger).to have_received(:warn).with("Database connection returned unexpected result ⚠️")
        expect(DatabaseHealthcheck).to have_received(:reconnect)
      end
    end

    context 'when connection throws error' do
      it 'reconnects and returns false' do
        expect(mock_connection).to receive(:execute).with("SELECT 1 AS health_check").and_raise(StandardError.new("Connection failed"))

        expect(DatabaseHealthcheck.check_connection).to be false
        expect(Rails.logger).to have_received(:error).with(/Database connection error detected ⚠️: Connection failed/)
        expect(DatabaseHealthcheck).to have_received(:reconnect)
      end
    end
  end

  describe '.check_pool_health' do
    let(:mock_pool) { double("ConnectionPool") }
    let(:mock_connections) { [] }

    before do
      # Mock everything needed by the method
      allow(ActiveRecord::Base).to receive(:connection_pool).and_return(mock_pool)
      allow(mock_pool).to receive(:connections).and_return(mock_connections)
      allow(mock_pool).to receive(:size).and_return(5)
      allow(mock_pool).to receive(:num_waiting_in_queue).and_return(0)

      # Completely stub out the reap_connections method to avoid implementation details
      allow(DatabaseHealthcheck).to receive(:reap_connections)

      # Mock logging
      allow(Rails.logger).to receive(:debug)
      allow(Rails.logger).to receive(:warn)
      allow(Rails.logger).to receive(:error)
      allow(Rails.logger).to receive(:info)
    end

    context 'when pool is healthy' do
      it 'returns true with proper stats' do
        # Create mock connections that are mostly idle
        3.times { mock_connections << double("Connection", in_use?: false) }
        2.times { mock_connections << double("Connection", in_use?: true) }

        expect(DatabaseHealthcheck.check_pool_health).to be true
        expect(Rails.logger).to have_received(:debug).with(/Connection pool is healthy/) if Rails.env.development?
      end
    end

    context 'when pool has high usage' do
      it 'returns false and logs warning' do
        # Create mock connections with very high usage (>80%)
        0.times { mock_connections << double("Connection", in_use?: false) }
        5.times { mock_connections << double("Connection", in_use?: true) }

        expect(DatabaseHealthcheck.check_pool_health).to be false
        expect(Rails.logger).to have_received(:warn).with(/Connection pool health issues detected/)
        expect(DatabaseHealthcheck).to have_received(:reap_connections)
      end
    end

    context 'when error occurs during check' do
      it 'returns false and logs error' do
        allow(mock_pool).to receive(:connections).and_raise(StandardError.new("Pool check failed"))

        expect(DatabaseHealthcheck.check_pool_health).to be false
        expect(Rails.logger).to have_received(:error).with(/Error checking connection pool health/)
      end
    end
  end

  describe '.verify_all_connections' do
    let(:mock_pool) { double("ConnectionPool") }
    let(:mock_connections) { [] }

    before do
      allow(ActiveRecord::Base).to receive(:connection_pool).and_return(mock_pool)
      allow(mock_pool).to receive(:connections).and_return(mock_connections)
      allow(mock_pool).to receive(:size).and_return(5)
      allow(Rails.logger).to receive(:debug)
      allow(Rails.logger).to receive(:info)
      allow(Rails.logger).to receive(:warn)
      allow(Rails.logger).to receive(:error)
    end

    context 'when all connections are good' do
      it 'returns true and verifies all connections' do
        3.times do
          conn = double("Connection")
          expect(conn).to receive(:verify!).and_return(true)
          mock_connections << conn
        end

        expect(DatabaseHealthcheck.verify_all_connections).to be true
        expect(Rails.logger).to have_received(:debug).with(/All 3 connections verified successfully/) if Rails.env.development?
      end
    end

    context 'when some connections are bad' do
      it 'removes bad connections and returns false' do
        # 2 good connections
        2.times do
          conn = double("Connection")
          expect(conn).to receive(:verify!).and_return(true)
          mock_connections << conn
        end

        # 1 bad connection
        bad_conn = double("Connection")
        expect(bad_conn).to receive(:verify!).and_raise(StandardError.new("Bad connection"))
        mock_connections << bad_conn

        expect(DatabaseHealthcheck.verify_all_connections).to be false
        expect(Rails.logger).to have_received(:warn).with(/Removing bad connection from pool/)
        expect(Rails.logger).to have_received(:info).with(/Removed 1 bad connections from pool/)
      end
    end

    context 'when error occurs during verification' do
      it 'returns false and logs error' do
        allow(mock_pool).to receive(:connections).and_raise(StandardError.new("Verification failed"))

        expect(DatabaseHealthcheck.verify_all_connections).to be false
        expect(Rails.logger).to have_received(:error).with(/Error verifying connections/)
      end
    end
  end
end
