require_relative '../../simple_test_helper'
require_relative '../../../app/services/astrology_service'

RSpec.describe AstrologyService do
  describe '.current_zodiac_sign' do
    context 'when date is within a zodiac sign range' do
      it 'returns Aries for March 21' do
        date = Date.new(2023, 3, 21)
        result = AstrologyService.current_zodiac_sign(date)
        expect(result[:name]).to eq('Aries')
      end

      it 'returns Taurus for April 20' do
        date = Date.new(2023, 4, 20)
        result = AstrologyService.current_zodiac_sign(date)
        expect(result[:name]).to eq('Taurus')
      end

      it 'returns Capricorn for December 25' do
        date = Date.new(2023, 12, 25)
        result = AstrologyService.current_zodiac_sign(date)
        expect(result[:name]).to eq('Capricorn')
      end

      it 'returns Capricorn for January 15' do
        date = Date.new(2023, 1, 15)
        result = AstrologyService.current_zodiac_sign(date)
        expect(result[:name]).to eq('Capricorn')
      end
    end
  end

  describe '.current_season' do
    it 'returns spring for March' do
      date = Date.new(2023, 3, 15)
      expect(AstrologyService.current_season(date)).to eq(:spring)
    end

    it 'returns summer for June' do
      date = Date.new(2023, 6, 15)
      expect(AstrologyService.current_season(date)).to eq(:summer)
    end

    it 'returns fall for October' do
      date = Date.new(2023, 10, 15)
      expect(AstrologyService.current_season(date)).to eq(:fall)
    end

    it 'returns winter for December' do
      date = Date.new(2023, 12, 15)
      expect(AstrologyService.current_season(date)).to eq(:winter)
    end
  end

  describe '.current_moon_phase' do
    it 'returns one of the eight moon phases' do
      date = Date.new(2023, 5, 15)
      expect(AstrologyService::MOON_PHASES).to include(AstrologyService.current_moon_phase(date))
    end
  end

  describe '.recommended_spread' do
    let(:date) { Date.new(2023, 4, 15) } # Aries period
    let(:zodiac) { AstrologyService.current_zodiac_sign(date) }
    let(:season) { AstrologyService.current_season(date) }
    let(:moon_phase) { AstrologyService.current_moon_phase(date) }

    it 'returns a hash with spread details' do
      result = AstrologyService.recommended_spread(date)

      expect(result).to be_a(Hash)
      expect(result[:name]).to eq("#{zodiac[:name]} #{moon_phase} Spread")
      expect(result[:positions]).to be_an(Array)
      expect(result[:positions].length).to eq(5)
    end

    it 'includes astrological context in the result' do
      result = AstrologyService.recommended_spread(date)
      context = result[:astrological_context]

      expect(context[:zodiac_sign]).to eq(zodiac[:name])
      expect(context[:element]).to eq(zodiac[:element])
      expect(context[:ruling_planet]).to eq(zodiac[:ruling_planet])
      expect(context[:season]).to eq(season.to_s)
    end
  end
end
