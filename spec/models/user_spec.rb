require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'validations' do
    it { should validate_uniqueness_of(:email).allow_nil }
    it { should validate_uniqueness_of(:external_id).scoped_to(:identity_provider_id).allow_nil }
    
    context 'when registered user' do
      before do
        allow(subject).to receive(:registered?).and_return(true)
      end
      
      it { should validate_presence_of(:password) }
      it { should validate_length_of(:password).is_at_least(6) }
    end
    
    context 'when not registered user' do
      before do
        allow(subject).to receive(:registered?).and_return(false)
      end
      
      it { should_not validate_presence_of(:password) }
    end
  end

  describe 'associations' do
    it { should belong_to(:identity_provider).optional }
    it { should have_many(:card_readings) }
    it { should have_many(:spreads) }
    it { should have_many(:reading_sessions) }
    it { should have_many(:tarot_cards).through(:card_readings) }
    it { should have_many(:subscriptions) }
  end

  describe 'factory' do
    it 'has a valid factory' do
      expect(build(:user)).to be_valid
    end

    it 'has a valid factory for anonymous users' do
      user = build(:user, :anonymous)
      expect(user).to be_valid
      expect(user.anonymous?).to be true
    end
    
    it 'has a valid factory for agent users' do
      user = build(:user, :agent)
      expect(user).to be_valid
      expect(user.agent?).to be true
    end
  end
end
