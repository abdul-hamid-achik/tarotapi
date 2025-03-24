require 'rails_helper'

RSpec.describe Organization, type: :model do
  describe 'factory' do
    it 'creates a valid organization' do
      organization = build(:organization)
      expect(organization).to be_valid
    end

    it 'handles features and quotas as JSON' do
      organization = create(:organization)

      # Test features access
      expect(organization.features).to be_a(Hash)
      expect(organization.features["max_members"]).to be_present
      expect(organization.max_members).to be_present

      # Test quotas access
      expect(organization.quotas).to be_a(Hash)
      expect(organization.quotas["daily_readings"]).to be_present
      expect(organization.daily_readings).to be_present

      # Test setting features works
      organization.max_members = 30
      organization.save
      organization.reload
      expect(organization.max_members).to eq(30)

      # Test different plan traits
      pro_org = create(:organization, :pro)
      expect(pro_org.features["priority_support"]).to be true

      free_org = create(:organization, :free)
      expect(free_org.features["white_label"]).to be false
    end
  end

  describe 'validations' do
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:plan) }
    it { should validate_presence_of(:billing_email) }
    it { should validate_presence_of(:status) }

    it { should validate_inclusion_of(:plan).in_array(%w[free basic pro enterprise]) }
    it { should validate_inclusion_of(:status).in_array(%w[active suspended cancelled]) }

    it 'validates billing_email format' do
      organization = build(:organization, billing_email: 'invalid-email')
      expect(organization).not_to be_valid
      expect(organization.errors[:billing_email]).to include("is invalid")
    end
  end

  describe 'associations' do
    it { should have_many(:memberships).dependent(:destroy) }
    it { should have_many(:users).through(:memberships) }
    it { should have_many(:api_keys).dependent(:destroy) }
    it { should have_many(:usage_logs).dependent(:destroy) }
  end

  describe 'scopes' do
    before do
      create(:organization, status: 'active', plan: 'free')
      create(:organization, status: 'active', plan: 'pro')
      create(:organization, status: 'suspended', plan: 'basic')
    end

    it 'active scope returns only active organizations' do
      expect(Organization.active.count).to eq(2)
      expect(Organization.active.pluck(:status).uniq).to eq([ 'active' ])
    end

    it 'by_plan scope returns organizations with the specified plan' do
      expect(Organization.by_plan('free').count).to eq(1)
      expect(Organization.by_plan('pro').count).to eq(1)
      expect(Organization.by_plan('basic').count).to eq(1)
    end
  end

  describe 'helper methods' do
    let(:organization) { create(:organization) }

    it 'active? returns true for active organizations' do
      organization.status = 'active'
      expect(organization.active?).to be true

      organization.status = 'suspended'
      expect(organization.active?).to be false
    end

    it 'suspended? returns true for suspended organizations' do
      organization.status = 'suspended'
      expect(organization.suspended?).to be true

      organization.status = 'active'
      expect(organization.suspended?).to be false
    end

    it 'cancelled? returns true for cancelled organizations' do
      organization.status = 'cancelled'
      expect(organization.cancelled?).to be true

      organization.status = 'active'
      expect(organization.cancelled?).to be false
    end
  end

  describe 'default features and quotas' do
    it 'sets free plan defaults' do
      organization = create(:organization, plan: 'free')
      expect(organization.features['max_members']).to eq(5)
      expect(organization.quotas['monthly_api_calls']).to eq(10_000)
    end

    it 'sets pro plan defaults' do
      organization = create(:organization, plan: 'pro')
      expect(organization.features['priority_support']).to be true
      expect(organization.quotas['concurrent_sessions']).to eq(250)
    end
  end
end
