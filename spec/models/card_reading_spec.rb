require 'rails_helper'

RSpec.describe CardReading, type: :model do
  describe 'associations' do
    it { should belong_to(:user) }
    it { should belong_to(:card) }
    it { should belong_to(:spread).optional }
    it { should belong_to(:reading).optional }
  end

  describe 'validations' do
    it { should validate_presence_of(:position) }
    it "allows is_reversed to be true or false" do
      reading = build(:card_reading, is_reversed: true)
      expect(reading).to be_valid

      reading = build(:card_reading, is_reversed: false)
      expect(reading).to be_valid
    end
  end

  describe 'callbacks' do
    it 'sets reading_date before create if not set' do
      freeze_time = Time.current
      allow(Time).to receive(:current).and_return(freeze_time)

      card_reading = build(:card_reading, reading_date: nil)
      card_reading.save!

      expect(card_reading.reading_date).to eq(freeze_time)
    end

    it 'does not override reading_date if already set' do
      custom_date = 2.days.ago
      card_reading = build(:card_reading, reading_date: custom_date)
      card_reading.save!

      expect(card_reading.reading_date).to eq(custom_date)
    end
  end

  describe 'factory' do
    it 'has a valid factory' do
      expect(build(:card_reading)).to be_valid
    end
  end
end
