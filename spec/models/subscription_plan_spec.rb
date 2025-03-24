require 'rails_helper'

RSpec.describe SubscriptionPlan, type: :model do
  describe 'associations' do
    it { should have_many(:subscriptions) }
  end

  describe 'validations' do
    it { should validate_presence_of(:name) }
    it { should validate_uniqueness_of(:name) }

    it { should validate_numericality_of(:price).is_greater_than_or_equal_to(0) }
    it { should validate_numericality_of(:price_cents).only_integer.is_greater_than_or_equal_to(0) }

    it { should allow_value(nil).for(:monthly_readings) }
    it { should validate_numericality_of(:monthly_readings).only_integer.is_greater_than_or_equal_to(0).allow_nil }

    it { should validate_numericality_of(:duration_days).only_integer.is_greater_than(0) }
  end

  describe 'scopes' do
    describe '.active' do
      before do
        @active_plan = create(:subscription_plan, is_active: true)
        @inactive_plan = create(:subscription_plan, is_active: false)
      end

      it 'returns only active plans' do
        expect(SubscriptionPlan.active).to include(@active_plan)
        expect(SubscriptionPlan.active).not_to include(@inactive_plan)
      end
    end
  end

  describe '#free?' do
    it 'returns true when price_cents is zero' do
      plan = build(:subscription_plan, price_cents: 0)
      expect(plan.free?).to be true
    end

    it 'returns false when price_cents is not zero' do
      plan = build(:subscription_plan, price_cents: 1000)
      expect(plan.free?).to be false
    end
  end

  describe '#features_list' do
    it 'returns the features array' do
      features = [ 'feature1', 'feature2' ]
      plan = build(:subscription_plan, features: features)
      expect(plan.features_list).to eq(features)
    end
  end

  describe '#has_feature?' do
    let(:plan) { build(:subscription_plan, features: [ 'premium_support', 'unlimited_readings', 'ai_analysis' ]) }

    it 'returns true when feature exists' do
      expect(plan.has_feature?('premium_support')).to be true
    end

    it 'returns true when feature exists as a symbol' do
      expect(plan.has_feature?(:premium_support)).to be true
    end

    it 'returns false when feature does not exist' do
      expect(plan.has_feature?('non_existent_feature')).to be false
    end

    it 'returns false when feature is nil' do
      expect(plan.has_feature?(nil)).to be false
    end
  end

  describe '#unlimited_readings?' do
    it 'returns true when reading_limit is nil' do
      plan = build(:subscription_plan, reading_limit: nil)
      expect(plan.unlimited_readings?).to be true
    end

    it 'returns false when reading_limit is not nil' do
      plan = build(:subscription_plan, reading_limit: 100)
      expect(plan.unlimited_readings?).to be false
    end
  end

  describe '#reading_limit' do
    it 'returns reading_limit if set' do
      plan = build(:subscription_plan, reading_limit: 50, monthly_readings: 30)
      expect(plan.reading_limit).to eq(50)
    end

    it 'returns monthly_readings if reading_limit is nil' do
      plan = build(:subscription_plan, reading_limit: nil, monthly_readings: 30)
      expect(plan.reading_limit).to eq(30)
    end
  end

  describe '#reading_limit=' do
    it 'sets reading_limit' do
      plan = build(:subscription_plan)
      plan.reading_limit = 75
      expect(plan.reading_limit).to eq(75)
    end

    it 'sets monthly_readings to same value if value is present' do
      plan = build(:subscription_plan)
      plan.reading_limit = 75
      expect(plan.monthly_readings).to eq(75)
    end

    it 'does not set monthly_readings if value is nil' do
      plan = build(:subscription_plan, monthly_readings: 30)
      plan.reading_limit = nil
      expect(plan.monthly_readings).to eq(30)
    end
  end

  describe 'factory' do
    it 'has a valid factory' do
      expect(build(:subscription_plan)).to be_valid
    end
  end
end
