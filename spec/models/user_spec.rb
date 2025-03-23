require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'validations' do
    it 'validates uniqueness of email when present' do
      create(:user, email: 'test@example.com', provider: 'email', uid: 'test@example.com')

      duplicate_user = build(:user, email: 'test@example.com')
      expect(duplicate_user).not_to be_valid
      expect(duplicate_user.errors[:email]).to include('has already been taken')

      # Test nil is allowed
      nil_user = build(:user, email: nil)
      nil_user.valid?
      expect(nil_user.errors[:email]).not_to include('has already been taken')
    end

    it 'validates uniqueness of external_id scoped to identity_provider_id when present' do
      identity_provider = create(:identity_provider)
      create(:user, external_id: 'ext1', identity_provider: identity_provider, uid: 'unique1')

      # Same external_id + provider should be invalid
      duplicate_user = build(:user, external_id: 'ext1', identity_provider: identity_provider, uid: 'unique2')
      expect(duplicate_user).not_to be_valid
      expect(duplicate_user.errors[:external_id]).to include('has already been taken')

      # Different provider should be valid
      different_provider = create(:identity_provider)
      different_provider_user = build(:user, external_id: 'ext1', identity_provider: different_provider, uid: 'unique3')
      different_provider_user.valid?
      expect(different_provider_user.errors[:external_id]).not_to include('has already been taken')

      # Nil external_id should be allowed
      nil_user = build(:user, external_id: nil, uid: 'unique4')
      nil_user.valid?
      expect(nil_user.errors[:external_id]).not_to include('has already been taken')
    end

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
    it { should have_many(:readings) }
    it { should have_many(:cards).through(:card_readings) }
    it { should have_many(:subscriptions) }
  end

  describe "factory" do
    it "has a valid factory" do
      expect(build(:user)).to be_valid
    end

    it "has a valid factory for anonymous users" do
      expect(build(:user, :anonymous)).to be_valid
    end

    it "has a valid factory for agent users" do
      expect(build(:user, :agent)).to be_valid
    end
  end
end
