require 'rails_helper'

RSpec.describe ReadingSerializer do
  let(:user) { create(:user) }
  let(:spread) { create(:spread, name: 'Celtic Cross') }
  let(:card_readings) { create_list(:card_reading, 3, user: user) }

  let(:reading) do
    create(:reading,
      user: user,
      spread: spread,
      question: "What does the future hold?",
      interpretation: "The cards suggest new opportunities ahead.",
      reading_date: Date.today,
      birth_date: Date.new(1990, 5, 14),
      name: "John Doe",
      astrological_context: {
        "zodiac_sign" => "Taurus",
        "moon_phase" => "Full Moon",
        "element" => "Earth",
        "season" => "spring"
      }
    )
  end

  before do
    # Associate card readings with the reading
    card_readings.each do |card_reading|
      card_reading.update(reading: reading)
    end

    # Mock NumerologyService calls
    allow(NumerologyService).to receive(:calculate_life_path_number).with(reading.birth_date).and_return(5)
    allow(NumerologyService).to receive(:calculate_name_number).with(reading.name).and_return(7)
  end

  describe 'serialized attributes' do
    let(:serialized_reading) { JSON.parse(ReadingSerializer.new(reading).serialized_json) }
    let(:attributes) { serialized_reading['data']['attributes'] }

    it 'includes standard attributes' do
      expect(attributes).to include(
        'question' => "What does the future hold?",
        'interpretation' => "The cards suggest new opportunities ahead.",
        'reading_date' => reading.reading_date.as_json,
        'birth_date' => reading.birth_date.as_json,
        'name' => "John Doe"
      )
    end

    it 'includes computed spread_name' do
      expect(attributes['spread_name']).to eq('Celtic Cross')
    end

    it 'includes card_count' do
      expect(attributes['card_count']).to eq(3)
    end

    it 'extracts astrological context attributes' do
      expect(attributes['zodiac_sign']).to eq('Taurus')
      expect(attributes['moon_phase']).to eq('Full Moon')
      expect(attributes['element']).to eq('Earth')
      expect(attributes['season']).to eq('Spring') # Note the capitalization
    end

    it 'includes calculated numerology values' do
      expect(attributes['life_path_number']).to eq(5)
      expect(attributes['name_number']).to eq(7)
    end
  end

  describe 'relationships' do
    let(:serialized_reading) { JSON.parse(ReadingSerializer.new(reading, include: [ :user, :spread, :card_readings ]).serialized_json) }

    it 'includes user relationship' do
      expect(serialized_reading['data']['relationships']['user']['data']['id']).to eq(user.id.to_s)
    end

    it 'includes spread relationship' do
      expect(serialized_reading['data']['relationships']['spread']['data']['id']).to eq(spread.id.to_s)
    end

    it 'includes card_readings relationship' do
      card_reading_ids = card_readings.map { |cr| cr.id.to_s }
      relationship_ids = serialized_reading['data']['relationships']['card_readings']['data'].map { |cr| cr['id'] }
      expect(relationship_ids).to match_array(card_reading_ids)
    end
  end

  context 'with nil values' do
    let(:reading_without_extras) do
      create(:reading,
        user: user,
        spread: nil,
        birth_date: nil,
        name: nil,
        astrological_context: nil
      )
    end

    let(:serialized_reading) { JSON.parse(ReadingSerializer.new(reading_without_extras).serialized_json) }
    let(:attributes) { serialized_reading['data']['attributes'] }

    it 'handles nil spread gracefully' do
      expect(attributes['spread_name']).to be_nil
    end

    it 'handles nil astrological context gracefully' do
      expect(attributes['zodiac_sign']).to be_nil
      expect(attributes['moon_phase']).to be_nil
      expect(attributes['element']).to be_nil
      expect(attributes['season']).to be_nil
    end

    it 'handles missing birth_date and name gracefully' do
      expect(attributes['life_path_number']).to be_nil
      expect(attributes['name_number']).to be_nil
    end

    it 'excludes spread relationship when no spread is present' do
      serialized = JSON.parse(ReadingSerializer.new(reading_without_extras, include: [ :spread ]).serialized_json)
      expect(serialized['data']['relationships']).not_to have_key('spread')
    end
  end
end
