require 'rails_helper'

RSpec.describe Spread, type: :model do
  describe 'associations' do
    it { should belong_to(:user).optional }
    it { should have_many(:card_readings).dependent(:nullify) }
    it { should have_many(:readings) }
  end

  describe 'validations' do
    it { should validate_presence_of(:name) }
    let(:spread) { create(:spread) }
    it { expect(spread).to validate_uniqueness_of(:name) }
    it { should validate_presence_of(:description) }
    it { should validate_presence_of(:positions) }
    it { should validate_presence_of(:num_cards) }
    it { should validate_numericality_of(:num_cards).is_greater_than(0) }
    it "allows is_public to be true or false" do
      spread = build(:spread, is_public: true)
      expect(spread).to be_valid

      spread = build(:spread, is_public: false)
      expect(spread).to be_valid
    end
  end

  describe 'scopes' do
    before do
      @user = create(:user)
      @system_spread = create(:spread, is_system: true, user: @user)
      @public_spread = create(:spread, is_public: true, is_system: false, user: @user)
      @private_spread = create(:spread, is_public: false, is_system: false, user: @user)
    end

    describe '.system_spreads' do
      it 'returns only system spreads' do
        result = Spread.system
        expect(result).to include(@system_spread)
        expect(result).not_to include(@public_spread)
        expect(result).not_to include(@private_spread)
      end
    end

    describe '.custom_spreads' do
      it 'returns only custom (non-system) spreads' do
        result = Spread.custom_spreads
        expect(result).not_to include(@system_spread)
        expect(result).to include(@public_spread)
        expect(result).to include(@private_spread)
      end
    end

    describe '.public_spreads' do
      it 'returns only public spreads' do
        result = Spread.public_spreads
        expect(result).to include(@system_spread) if @system_spread.is_public
        expect(result).to include(@public_spread)
        expect(result).not_to include(@private_spread)
      end
    end
  end

  describe '.default_spread' do
    it 'delegates to SpreadService.default_spread' do
      default_spread = double('default_spread')
      allow(SpreadService).to receive(:default_spread).and_return(default_spread)

      expect(Spread.default_spread).to eq(default_spread)
      expect(SpreadService).to have_received(:default_spread)
    end
  end

  describe '#system?' do
    it 'returns true if spread is a system spread' do
      spread = build(:spread, is_system: true)
      expect(spread.system?).to be true
    end

    it 'returns false if spread is not a system spread' do
      spread = build(:spread, is_system: false)
      expect(spread.system?).to be false
    end
  end

  describe 'factory' do
    it 'has a valid factory' do
      expect(build(:spread)).to be_valid
    end
  end
end
