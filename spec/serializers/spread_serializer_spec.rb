require 'rails_helper'

RSpec.describe SpreadSerializer do
  let(:user) { create(:user) }
  let(:card_readings) { create_list(:card_reading, 3, user: user) }

  let(:spread) do
    create(:spread,
      name: 'Celtic Cross',
      description: 'A classic 10-card spread',
      positions: [
        { 'name' => 'Present', 'description' => 'Current situation' },
        { 'name' => 'Challenge', 'description' => 'Immediate challenge' },
        { 'name' => 'Distant Past', 'description' => 'Foundation of the situation' }
      ],
      is_public: true,
      user: user,
      astrological_context: {
        'zodiac_sign' => 'Taurus',
        'moon_phase' => 'Full Moon',
        'element' => 'Earth',
        'season' => 'spring'
      }
    )
  end

  before do
    # Associate card readings with the spread
    card_readings.each do |card_reading|
      card_reading.update(spread: spread)
    end
  end

  describe 'serialized attributes' do
    let(:serialized_spread) { JSON.parse(SpreadSerializer.new(spread).serialized_json) }
    let(:attributes) { serialized_spread['data']['attributes'] }

    it 'includes standard attributes' do
      expect(attributes).to include(
        'name' => 'Celtic Cross',
        'description' => 'A classic 10-card spread',
        'is_public' => true
      )
    end

    it 'includes positions array' do
      expect(attributes['positions']).to be_an(Array)
      expect(attributes['positions'].size).to eq(3)
      expect(attributes['positions'].first['name']).to eq('Present')
    end

    it 'includes position_count' do
      expect(attributes['position_count']).to eq(3)
    end

    it 'extracts astrological context attributes' do
      expect(attributes['zodiac_sign']).to eq('Taurus')
      expect(attributes['moon_phase']).to eq('Full Moon')
      expect(attributes['element']).to eq('Earth')
      expect(attributes['season']).to eq('Spring') # Note the capitalization
    end
  end

  describe 'relationships' do
    let(:serialized_spread) { JSON.parse(SpreadSerializer.new(spread, include: [ :user, :card_readings ]).serialized_json) }

    it 'includes user relationship' do
      expect(serialized_spread['data']['relationships']['user']['data']['id']).to eq(user.id.to_s)
    end

    it 'includes card_readings relationship' do
      card_reading_ids = card_readings.map { |cr| cr.id.to_s }
      relationship_ids = serialized_spread['data']['relationships']['card_readings']['data'].map { |cr| cr['id'] }
      expect(relationship_ids).to match_array(card_reading_ids)
    end
  end

  context 'with nil values' do
    let(:spread_without_extras) do
      create(:spread,
        user: user,
        positions: [], # Empty positions array
        astrological_context: nil
      )
    end

    let(:serialized_spread) { JSON.parse(SpreadSerializer.new(spread_without_extras).serialized_json) }
    let(:attributes) { serialized_spread['data']['attributes'] }

    it 'handles empty positions array gracefully' do
      expect(attributes['positions']).to eq([])
      expect(attributes['position_count']).to eq(0)
    end

    it 'handles nil astrological context gracefully' do
      expect(attributes['zodiac_sign']).to be_nil
      expect(attributes['moon_phase']).to be_nil
      expect(attributes['element']).to be_nil
      expect(attributes['season']).to be_nil
    end
  end

  context 'with system spread' do
    let(:system_spread) do
      create(:spread,
        name: 'Three Card',
        is_public: true,
        is_system: true,
        user: user
      )
    end

    let(:serialized_spread) { JSON.parse(SpreadSerializer.new(system_spread).serialized_json) }

    it 'serializes system spread properties correctly' do
      expect(serialized_spread['data']['attributes']['is_public']).to be true
    end
  end
end
