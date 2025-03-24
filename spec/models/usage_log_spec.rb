require 'rails_helper'

RSpec.describe UsageLog, type: :model do
  describe 'associations' do
    it { should belong_to(:organization) }
    it { should belong_to(:user).optional }
  end

  describe 'validations' do
    it { should validate_presence_of(:organization_id) }
    it { should validate_presence_of(:metric_type) }
    it { should validate_presence_of(:recorded_at) }
    it { should validate_presence_of(:metadata) }
  end

  describe 'scopes' do
    let!(:api_call_log) { create(:usage_log, :api_call) }
    let!(:reading_log) { create(:usage_log, :reading) }
    let!(:session_log) { create(:usage_log, :session, recorded_at: 15.minutes.ago) }
    let!(:old_session_log) { create(:usage_log, :session, recorded_at: 2.hours.ago) }
    let!(:error_log) { create(:usage_log, :error) }
    let!(:failed_log) { create(:usage_log, :failed) }

    describe '.api_calls' do
      it 'returns only api_call logs' do
        expect(described_class.api_calls).to include(api_call_log)
        expect(described_class.api_calls).not_to include(reading_log)
        expect(described_class.api_calls).not_to include(session_log)
        expect(described_class.api_calls).not_to include(error_log)
      end
    end

    describe '.readings' do
      it 'returns only reading logs' do
        expect(described_class.readings).to include(reading_log)
        expect(described_class.readings).not_to include(api_call_log)
        expect(described_class.readings).not_to include(session_log)
        expect(described_class.readings).not_to include(error_log)
      end
    end

    describe '.active_sessions' do
      it 'returns only session logs newer than 30 minutes' do
        expect(described_class.active_sessions).to include(session_log)
        expect(described_class.active_sessions).not_to include(old_session_log)
        expect(described_class.active_sessions).not_to include(api_call_log)
        expect(described_class.active_sessions).not_to include(reading_log)
      end
    end

    describe '.by_date_range' do
      it 'returns logs within the given date range' do
        yesterday = 1.day.ago
        tomorrow = 1.day.from_now
        recent_log = create(:usage_log, recorded_at: Time.current)
        old_log = create(:usage_log, recorded_at: 1.week.ago)

        result = described_class.by_date_range(yesterday, tomorrow)
        expect(result).to include(recent_log)
        expect(result).not_to include(old_log)
      end
    end

    describe '.by_metric_type' do
      it 'returns logs of the specified type' do
        expect(described_class.by_metric_type('reading')).to include(reading_log)
        expect(described_class.by_metric_type('reading')).not_to include(api_call_log)
        expect(described_class.by_metric_type('api_call')).to include(api_call_log)
        expect(described_class.by_metric_type('api_call')).not_to include(reading_log)
      end
    end

    describe '.successful' do
      it 'returns logs with 2xx status codes' do
        expect(described_class.successful).to include(api_call_log)
        expect(described_class.successful).not_to include(failed_log)
      end
    end

    describe '.failed' do
      it 'returns logs with 5xx status codes' do
        expect(described_class.failed).to include(failed_log)
        expect(described_class.failed).not_to include(api_call_log)
      end
    end
  end

  describe 'class methods' do
    let(:organization) { create(:organization) }
    let(:user) { create(:user) }

    describe '.record_api_call!' do
      it 'creates a new api_call log with correct attributes' do
        expect {
          described_class.record_api_call!(
            organization: organization,
            user: user,
            endpoint: '/api/v1/readings',
            status: '200',
            response_time: 150
          )
        }.to change(described_class, :count).by(1)

        log = described_class.last
        expect(log.organization).to eq(organization)
        expect(log.user).to eq(user)
        expect(log.metric_type).to eq('api_call')
        expect(log.endpoint).to eq('/api/v1/readings')
        expect(log.status).to eq('200')
        expect(log.response_time).to eq(150)
      end

      it 'works without a user' do
        expect {
          described_class.record_api_call!(
            organization: organization,
            endpoint: '/api/v1/readings',
            status: '200',
            response_time: 150
          )
        }.to change(described_class, :count).by(1)

        log = described_class.last
        expect(log.organization).to eq(organization)
        expect(log.user).to be_nil
      end
    end

    describe '.record_reading!' do
      it 'creates a new reading log with correct attributes' do
        expect {
          described_class.record_reading!(
            organization: organization,
            user: user
          )
        }.to change(described_class, :count).by(1)

        log = described_class.last
        expect(log.organization).to eq(organization)
        expect(log.user).to eq(user)
        expect(log.metric_type).to eq('reading')
      end
    end

    describe '.record_session!' do
      it 'creates a new session log with correct attributes' do
        # Create some active sessions first
        create_list(:usage_log, 3, :session, organization: organization, recorded_at: 10.minutes.ago)

        expect {
          described_class.record_session!(
            organization: organization,
            user: user
          )
        }.to change(described_class, :count).by(1)

        log = described_class.last
        expect(log.organization).to eq(organization)
        expect(log.user).to eq(user)
        expect(log.metric_type).to eq('session')
        expect(log.concurrent_count).to eq(4) # 3 existing + 1 new
      end
    end

    describe '.record_error!' do
      it 'creates a new error log with correct attributes' do
        expect {
          described_class.record_error!(
            organization: organization,
            user: user,
            error_message: 'Database connection error',
            endpoint: '/api/v1/readings'
          )
        }.to change(described_class, :count).by(1)

        log = described_class.last
        expect(log.organization).to eq(organization)
        expect(log.user).to eq(user)
        expect(log.metric_type).to eq('error')
        expect(log.error_message).to eq('Database connection error')
        expect(log.endpoint).to eq('/api/v1/readings')
      end

      it 'works without a user and endpoint' do
        expect {
          described_class.record_error!(
            organization: organization,
            error_message: 'System error'
          )
        }.to change(described_class, :count).by(1)

        log = described_class.last
        expect(log.organization).to eq(organization)
        expect(log.user).to be_nil
        expect(log.endpoint).to be_nil
        expect(log.error_message).to eq('System error')
      end
    end

    describe '.track!' do
      it 'creates a generic log with given parameters' do
        metadata = { custom: 'value', another: 123 }

        expect {
          described_class.track!(
            organization,
            'custom_event',
            user,
            metadata
          )
        }.to change(described_class, :count).by(1)

        log = described_class.last
        expect(log.organization).to eq(organization)
        expect(log.user).to eq(user)
        expect(log.metric_type).to eq('custom_event')
        expect(log.metadata).to include(metadata)
      end
    end

    describe '.daily_metrics' do
      before do
        # Create logs across different days
        Timecop.freeze(1.day.ago) do
          create_list(:usage_log, 2, :api_call, recorded_at: Time.current)
          create(:usage_log, :reading, recorded_at: Time.current)
        end

        Timecop.freeze(Time.current) do
          create(:usage_log, :api_call, recorded_at: Time.current)
          create_list(:usage_log, 3, :reading, recorded_at: Time.current)
        end
      end

      it 'returns metrics grouped by day and type' do
        metrics = described_class.daily_metrics
        expect(metrics.size).to eq(4) # 2 days × 2 types

        yesterday = 1.day.ago.beginning_of_day
        today = Time.current.beginning_of_day

        # Test structure looks like: {[date, type] => count}
        expect(metrics.keys.map(&:first).uniq.size).to eq(2) # 2 distinct days
        expect(metrics.keys.map(&:second).uniq.sort).to eq([ 'api_call', 'reading' ])
      end
    end

    describe '.average_response_time' do
      before do
        create(:usage_log, :api_call, metadata: { endpoint: '/api/v1/test', status: '200', response_time: 100 })
        create(:usage_log, :api_call, metadata: { endpoint: '/api/v1/test', status: '200', response_time: 200 })
        create(:usage_log, :api_call, metadata: { endpoint: '/api/v1/test', status: '200', response_time: 300 })
        create(:usage_log, :reading) # Should be ignored
      end

      it 'calculates average response time for api calls' do
        avg = described_class.average_response_time
        expect(avg).to eq(200) # (100 + 200 + 300) / 3
      end
    end

    describe '.error_rate' do
      before do
        # Create 8 successful and 2 failed API calls
        create_list(:usage_log, 8, :api_call)
        create_list(:usage_log, 2, :failed)
      end

      it 'calculates error rate as percentage' do
        rate = described_class.error_rate
        expect(rate).to eq(20.0) # 2 / 10 * 100 = 20%
      end

      it 'returns 0 when there are no API calls' do
        UsageLog.delete_all
        rate = described_class.error_rate
        expect(rate).to eq(0)
      end
    end
  end

  describe 'instance methods' do
    describe '#api_call?' do
      it 'returns true for api_call logs' do
        log = build(:usage_log, :api_call)
        expect(log.api_call?).to be true
      end

      it 'returns false for other log types' do
        log = build(:usage_log, :reading)
        expect(log.api_call?).to be false
      end
    end

    describe '#reading?' do
      it 'returns true for reading logs' do
        log = build(:usage_log, :reading)
        expect(log.reading?).to be true
      end

      it 'returns false for other log types' do
        log = build(:usage_log, :api_call)
        expect(log.reading?).to be false
      end
    end

    describe '#session?' do
      it 'returns true for session logs' do
        log = build(:usage_log, :session)
        expect(log.session?).to be true
      end

      it 'returns false for other log types' do
        log = build(:usage_log, :api_call)
        expect(log.session?).to be false
      end
    end

    describe '#error?' do
      it 'returns true for error logs' do
        log = build(:usage_log, :error)
        expect(log.error?).to be true
      end

      it 'returns false for other log types' do
        log = build(:usage_log, :api_call)
        expect(log.error?).to be false
      end
    end

    describe '#successful?' do
      it 'returns true for logs with 2xx status' do
        log = build(:usage_log, metadata: { status: '200' })
        expect(log.successful?).to be true
      end

      it 'returns false for logs with non-2xx status' do
        log = build(:usage_log, metadata: { status: '500' })
        expect(log.successful?).to be false
      end

      it 'handles missing status gracefully' do
        log = build(:usage_log, metadata: {})
        expect(log.successful?).to be false
      end
    end

    describe '#failed?' do
      it 'returns true for logs with 5xx status' do
        log = build(:usage_log, metadata: { status: '500' })
        expect(log.failed?).to be true
      end

      it 'returns false for logs with non-5xx status' do
        log = build(:usage_log, metadata: { status: '200' })
        expect(log.failed?).to be false
      end

      it 'handles missing status gracefully' do
        log = build(:usage_log, metadata: {})
        expect(log.failed?).to be false
      end
    end

    describe '#response_time' do
      it 'returns response time as float' do
        log = build(:usage_log, metadata: { response_time: '150.5' })
        expect(log.response_time).to eq(150.5)
      end

      it 'returns 0 for missing response time' do
        log = build(:usage_log, metadata: {})
        expect(log.response_time).to eq(0)
      end
    end
  end

  describe 'factory' do
    it 'has a valid factory' do
      expect(build(:usage_log)).to be_valid
    end

    it 'has a valid api_call trait' do
      log = build(:usage_log, :api_call)
      expect(log).to be_valid
      expect(log.metric_type).to eq('api_call')
    end

    it 'has a valid reading trait' do
      log = build(:usage_log, :reading)
      expect(log).to be_valid
      expect(log.metric_type).to eq('reading')
    end

    it 'has a valid session trait' do
      log = build(:usage_log, :session)
      expect(log).to be_valid
      expect(log.metric_type).to eq('session')
    end

    it 'has a valid error trait' do
      log = build(:usage_log, :error)
      expect(log).to be_valid
      expect(log.metric_type).to eq('error')
    end

    it 'has a valid failed trait' do
      log = build(:usage_log, :failed)
      expect(log).to be_valid
      expect(log.status).to eq('500')
    end

    it 'has a valid without_user trait' do
      log = build(:usage_log, :without_user)
      expect(log).to be_valid
      expect(log.user).to be_nil
    end
  end
end
