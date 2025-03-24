require 'rails_helper'

RSpec.describe ReadingQuota, type: :model do
  describe 'associations' do
    it { should belong_to(:user) }
  end

  describe 'validations' do
    it { should validate_presence_of(:monthly_limit) }
    it { should validate_numericality_of(:monthly_limit).is_greater_than_or_equal_to(0) }

    it { should validate_presence_of(:readings_this_month) }
    it { should validate_numericality_of(:readings_this_month).is_greater_than_or_equal_to(0) }

    it { should validate_presence_of(:reset_date) }

    it { should validate_presence_of(:llm_calls_this_month) }
    it { should validate_numericality_of(:llm_calls_this_month).is_greater_than_or_equal_to(0) }

    it { should validate_presence_of(:llm_calls_limit) }
    it { should validate_numericality_of(:llm_calls_limit).is_greater_than_or_equal_to(0) }
  end

  describe 'instance methods' do
    let(:user) { create(:user) }
    let!(:reading_quota) { create(:reading_quota, user: user, monthly_limit: 10, readings_this_month: 5,
                                 llm_calls_limit: 100, llm_calls_this_month: 50,
                                 reset_date: Date.today.end_of_month) }

    describe '#remaining' do
      it 'returns the difference between monthly limit and readings this month' do
        expect(reading_quota.remaining).to eq(5)
      end
    end

    describe '#llm_calls_remaining' do
      it 'returns the difference between llm calls limit and llm calls this month' do
        expect(reading_quota.llm_calls_remaining).to eq(50)
      end
    end

    describe '#increment_usage!' do
      context 'when user has no active subscription' do
        before do
          allow(user).to receive(:subscription_status).and_return('inactive')
        end

        it 'increments readings_this_month by 1' do
          expect { reading_quota.increment_usage! }.to change { reading_quota.readings_this_month }.by(1)
        end
      end

      context 'when user has active subscription' do
        before do
          allow(user).to receive(:subscription_status).and_return('active')
        end

        it 'does not increment readings_this_month' do
          expect { reading_quota.increment_usage! }.not_to change { reading_quota.readings_this_month }
        end
      end
    end

    describe '#increment_llm_call!' do
      context 'when user has no active subscription' do
        before do
          allow(user).to receive(:subscription_status).and_return('inactive')
        end

        it 'increments llm_calls_this_month by 1 by default' do
          expect { reading_quota.increment_llm_call! }.to change { reading_quota.llm_calls_this_month }.by(1)
        end

        it 'increments llm_calls_this_month by the multiplier' do
          expect { reading_quota.increment_llm_call!(3) }.to change { reading_quota.llm_calls_this_month }.by(3)
        end

        it 'updates last_llm_call_at timestamp' do
          expect { reading_quota.increment_llm_call! }.to change { reading_quota.last_llm_call_at }
        end
      end

      context 'when user has active subscription with unlimited tier' do
        before do
          allow(user).to receive(:subscription_status).and_return('active')
          allow(reading_quota).to receive(:unlimited_llm_tier?).and_return(true)
        end

        it 'does not increment llm_calls_this_month' do
          expect { reading_quota.increment_llm_call! }.not_to change { reading_quota.llm_calls_this_month }
        end
      end
    end

    describe '#exceeded?' do
      it 'returns true when remaining is 0' do
        reading_quota.update!(readings_this_month: 10)
        expect(reading_quota.exceeded?).to be true
      end

      it 'returns true when remaining is negative' do
        reading_quota.update!(readings_this_month: 15)
        expect(reading_quota.exceeded?).to be true
      end

      it 'returns false when there are readings remaining' do
        reading_quota.update!(readings_this_month: 8)
        expect(reading_quota.exceeded?).to be false
      end
    end

    describe '#llm_calls_exceeded?' do
      context 'when not in unlimited tier' do
        before do
          allow(reading_quota).to receive(:unlimited_llm_tier?).and_return(false)
        end

        it 'returns true when llm_calls_remaining is 0' do
          reading_quota.update!(llm_calls_this_month: 100)
          expect(reading_quota.llm_calls_exceeded?).to be true
        end

        it 'returns true when llm_calls_remaining is negative' do
          reading_quota.update!(llm_calls_this_month: 110)
          expect(reading_quota.llm_calls_exceeded?).to be true
        end

        it 'returns false when there are llm calls remaining' do
          reading_quota.update!(llm_calls_this_month: 90)
          expect(reading_quota.llm_calls_exceeded?).to be false
        end
      end

      context 'when in unlimited tier' do
        before do
          allow(reading_quota).to receive(:unlimited_llm_tier?).and_return(true)
        end

        it 'always returns false regardless of usage' do
          reading_quota.update!(llm_calls_this_month: 1000)
          expect(reading_quota.llm_calls_exceeded?).to be false
        end
      end
    end

    describe '#almost_exceeded?' do
      it 'returns true when remaining is between 1 and 5' do
        reading_quota.update!(readings_this_month: 6)
        expect(reading_quota.almost_exceeded?).to be true

        reading_quota.update!(readings_this_month: 9)
        expect(reading_quota.almost_exceeded?).to be true
      end

      it 'returns false when remaining is 0' do
        reading_quota.update!(readings_this_month: 10)
        expect(reading_quota.almost_exceeded?).to be false
      end

      it 'returns false when remaining is greater than 5' do
        reading_quota.update!(readings_this_month: 3)
        expect(reading_quota.almost_exceeded?).to be false
      end
    end

    describe '#llm_calls_almost_exceeded?' do
      context 'when not in unlimited tier' do
        before do
          allow(reading_quota).to receive(:unlimited_llm_tier?).and_return(false)
        end

        it 'returns true when llm_calls_remaining is between 1 and 20' do
          reading_quota.update!(llm_calls_this_month: 85)
          expect(reading_quota.llm_calls_almost_exceeded?).to be true

          reading_quota.update!(llm_calls_this_month: 99)
          expect(reading_quota.llm_calls_almost_exceeded?).to be true
        end

        it 'returns false when llm_calls_remaining is 0' do
          reading_quota.update!(llm_calls_this_month: 100)
          expect(reading_quota.llm_calls_almost_exceeded?).to be false
        end

        it 'returns false when llm_calls_remaining is greater than 20' do
          reading_quota.update!(llm_calls_this_month: 70)
          expect(reading_quota.llm_calls_almost_exceeded?).to be false
        end
      end

      context 'when in unlimited tier' do
        before do
          allow(reading_quota).to receive(:unlimited_llm_tier?).and_return(true)
        end

        it 'always returns false regardless of usage' do
          reading_quota.update!(llm_calls_this_month: 95)
          expect(reading_quota.llm_calls_almost_exceeded?).to be false
        end
      end
    end

    describe '#should_reset?' do
      it 'returns true when reset_date is in the past' do
        reading_quota.update!(reset_date: 1.day.ago)
        expect(reading_quota.should_reset?).to be true
      end

      it 'returns true when reset_date is today' do
        reading_quota.update!(reset_date: Time.current)
        expect(reading_quota.should_reset?).to be true
      end

      it 'returns false when reset_date is in the future' do
        reading_quota.update!(reset_date: 1.day.from_now)
        expect(reading_quota.should_reset?).to be false
      end
    end

    describe '#reset!' do
      it 'resets readings_this_month to 0' do
        reading_quota.update!(readings_this_month: 8)
        reading_quota.reset!
        expect(reading_quota.readings_this_month).to eq(0)
      end

      it 'resets llm_calls_this_month to 0' do
        reading_quota.update!(llm_calls_this_month: 75)
        reading_quota.reset!
        expect(reading_quota.llm_calls_this_month).to eq(0)
      end

      it 'sets reset_date to the first day of next month' do
        original_date = Date.today
        travel_to original_date do
          reading_quota.reset!
          expected_date = original_date.end_of_month + 1.day
          expect(reading_quota.reset_date).to eq(expected_date)
        end
      end
    end

    describe '#reset_llm_calls!' do
      it 'resets only llm_calls_this_month to 0' do
        reading_quota.update!(readings_this_month: 7, llm_calls_this_month: 80)
        reading_quota.reset_llm_calls!
        expect(reading_quota.llm_calls_this_month).to eq(0)
        expect(reading_quota.readings_this_month).to eq(7)
      end
    end
  end
end
