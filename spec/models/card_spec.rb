require 'rails_helper'

RSpec.describe Card, type: :model do
  describe 'associations' do
    it { should have_one_attached(:image) }
    it { should have_many(:card_readings) }
    it { should have_many(:users).through(:card_readings) }
    it { should have_many(:readings).through(:card_readings) }
  end

  describe 'validations' do
    it { should validate_presence_of(:name) }
    it { should validate_uniqueness_of(:name) }
    it { should validate_presence_of(:arcana) }
    it { should validate_presence_of(:description) }

    context 'when arcana is major' do
      before do
        allow(subject).to receive(:major_arcana?).and_return(true)
        allow(subject).to receive(:minor_arcana?).and_return(false)
      end

      it { should validate_presence_of(:rank) }
      it { should_not validate_presence_of(:suit) }
    end

    context 'when arcana is minor' do
      before do
        allow(subject).to receive(:major_arcana?).and_return(false)
        allow(subject).to receive(:minor_arcana?).and_return(true)
      end

      it { should_not validate_presence_of(:rank) }
      it { should validate_presence_of(:suit) }
    end
  end

  describe '#major_arcana?' do
    it 'returns true if arcana is major' do
      card = build(:card, arcana: 'major')
      expect(card.major_arcana?).to be true
    end

    it 'returns false if arcana is not major' do
      card = build(:card, arcana: 'minor')
      expect(card.major_arcana?).to be false
    end
  end

  describe '#minor_arcana?' do
    it 'returns true if arcana is minor' do
      card = build(:card, arcana: 'minor')
      expect(card.minor_arcana?).to be true
    end

    it 'returns false if arcana is not minor' do
      card = build(:card, arcana: 'major')
      expect(card.minor_arcana?).to be false
    end
  end

  describe 'factory' do
    it 'has a valid factory' do
      expect(build(:card)).to be_valid
    end

    it 'creates a valid major arcana card' do
      card = build(:card, arcana: 'major', rank: '0', suit: nil)
      expect(card).to be_valid
    end

    it 'creates a valid minor arcana card' do
      card = build(:card, arcana: 'minor', rank: nil, suit: 'wands')
      expect(card).to be_valid
    end
  end
end
