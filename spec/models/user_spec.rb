require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'validations' do
    it { should validate_presence_of(:email) }
    it { should validate_uniqueness_of(:email).case_insensitive }
    it { should validate_presence_of(:username) }
    it { should validate_uniqueness_of(:username).case_insensitive }
  end

  describe 'associations' do
    it { should have_many(:identity_providers).dependent(:destroy) }
    it { should have_many(:reading_sessions).dependent(:destroy) }
  end

  describe 'factory' do
    it 'has a valid factory' do
      expect(build(:user)).to be_valid
    end

    it 'has a valid factory with identity provider' do
      user = create(:user, :with_identity_provider)
      expect(user.identity_providers.count).to eq(1)
    end
  end
end
