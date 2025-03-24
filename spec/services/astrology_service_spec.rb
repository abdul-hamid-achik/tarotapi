require 'rails_helper'

RSpec.describe AstrologyService do
  describe '.current_zodiac_sign' do
    context 'when date is within a zodiac sign range' do
      it 'returns Aries for March 21' do
        date = Date.new(2023, 3, 21)
        result = AstrologyService.current_zodiac_sign(date)
        expect(result[:name]).to eq('Aries')
      end

      it 'returns Aries for April 19' do
        date = Date.new(2023, 4, 19)
        result = AstrologyService.current_zodiac_sign(date)
        expect(result[:name]).to eq('Aries')
      end

      it 'returns Taurus for April 20' do
        date = Date.new(2023, 4, 20)
        result = AstrologyService.current_zodiac_sign(date)
        expect(result[:name]).to eq('Taurus')
      end

      it 'returns Leo for August 15' do
        date = Date.new(2023, 8, 15)
        result = AstrologyService.current_zodiac_sign(date)
        expect(result[:name]).to eq('Leo')
      end

      it 'returns Scorpio for November 15' do
        date = Date.new(2023, 11, 15)
        result = AstrologyService.current_zodiac_sign(date)
        expect(result[:name]).to eq('Scorpio')
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

      it 'returns Pisces for March 15' do
        date = Date.new(2023, 3, 15)
        result = AstrologyService.current_zodiac_sign(date)
        expect(result[:name]).to eq('Pisces')
      end
    end

    context 'when no date is provided' do
      it 'uses the current date' do
        expected_sign = nil

        # Find the expected sign for today
        today = Date.current
        expected_sign = AstrologyService::ZODIAC_SIGNS.find do |sign|
          month = today.month
          day = today.day
          start_month, start_day = sign[:start_date]
          end_month, end_day = sign[:end_date]

          if start_month == end_month
            month == start_month && day >= start_day && day <= end_day
          elsif start_month > end_month # Handles zodiac signs that span year boundary
            (month == start_month && day >= start_day) || (month == end_month && day <= end_day)
          else
            (month == start_month && day >= start_day) ||
            (month > start_month && month < end_month) ||
            (month == end_month && day <= end_day)
          end
        end

        result = AstrologyService.current_zodiac_sign
        expect(result[:name]).to eq(expected_sign[:name])
      end
    end
  end

  describe '.current_season' do
    it 'returns spring for March' do
      date = Date.new(2023, 3, 15)
      expect(AstrologyService.current_season(date)).to eq(:spring)
    end

    it 'returns spring for April' do
      date = Date.new(2023, 4, 15)
      expect(AstrologyService.current_season(date)).to eq(:spring)
    end

    it 'returns spring for May' do
      date = Date.new(2023, 5, 15)
      expect(AstrologyService.current_season(date)).to eq(:spring)
    end

    it 'returns summer for June' do
      date = Date.new(2023, 6, 15)
      expect(AstrologyService.current_season(date)).to eq(:summer)
    end

    it 'returns summer for July' do
      date = Date.new(2023, 7, 15)
      expect(AstrologyService.current_season(date)).to eq(:summer)
    end

    it 'returns summer for August' do
      date = Date.new(2023, 8, 15)
      expect(AstrologyService.current_season(date)).to eq(:summer)
    end

    it 'returns fall for September' do
      date = Date.new(2023, 9, 15)
      expect(AstrologyService.current_season(date)).to eq(:fall)
    end

    it 'returns fall for October' do
      date = Date.new(2023, 10, 15)
      expect(AstrologyService.current_season(date)).to eq(:fall)
    end

    it 'returns fall for November' do
      date = Date.new(2023, 11, 15)
      expect(AstrologyService.current_season(date)).to eq(:fall)
    end

    it 'returns winter for December' do
      date = Date.new(2023, 12, 15)
      expect(AstrologyService.current_season(date)).to eq(:winter)
    end

    it 'returns winter for January' do
      date = Date.new(2023, 1, 15)
      expect(AstrologyService.current_season(date)).to eq(:winter)
    end

    it 'returns winter for February' do
      date = Date.new(2023, 2, 15)
      expect(AstrologyService.current_season(date)).to eq(:winter)
    end

    it 'uses the current date when no date is provided' do
      today = Date.current
      month = today.month
      expected_season = case month
      when 3, 4, 5 then :spring
      when 6, 7, 8 then :summer
      when 9, 10, 11 then :fall
      else :winter
      end

      expect(AstrologyService.current_season).to eq(expected_season)
    end
  end

  describe '.current_moon_phase' do
    it 'returns one of the eight moon phases' do
      date = Date.new(2023, 5, 15)
      expect(AstrologyService::MOON_PHASES).to include(AstrologyService.current_moon_phase(date))
    end

    it 'returns a different phase for dates separated by ~3.7 days' do
      date1 = Date.new(2023, 5, 1)
      date2 = date1 + 4

      phase1 = AstrologyService.current_moon_phase(date1)
      phase2 = AstrologyService.current_moon_phase(date2)

      expect(phase1).not_to eq(phase2)
    end

    it 'uses the current date when no date is provided' do
      moon_phase = AstrologyService.current_moon_phase
      expect(AstrologyService::MOON_PHASES).to include(moon_phase)
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
      expect(result[:description]).to include(zodiac[:name])
      expect(result[:description]).to include(moon_phase)
      expect(result[:positions]).to be_an(Array)
      expect(result[:positions].length).to eq(5)
      expect(result[:astrological_context]).to be_a(Hash)
    end

    it 'includes astrological context in the result' do
      result = AstrologyService.recommended_spread(date)
      context = result[:astrological_context]

      expect(context[:zodiac_sign]).to eq(zodiac[:name])
      expect(context[:element]).to eq(zodiac[:element])
      expect(context[:ruling_planet]).to eq(zodiac[:ruling_planet])
      expect(context[:season]).to eq(season.to_s)
      expect(context[:moon_phase]).to eq(moon_phase)
    end

    it 'creates position cards that reference astrological elements' do
      result = AstrologyService.recommended_spread(date)
      positions = result[:positions]

      # Each position should reference some astrological element
      expect(positions[0]["name"]).to eq("Current Energy")
      expect(positions[1]["name"]).to eq("#{zodiac[:element]} Influence")
      expect(positions[2]["name"]).to eq("#{zodiac[:ruling_planet]} Guidance")
      expect(positions[3]["name"]).to eq("#{season.to_s.capitalize} Path")
      expect(positions[4]["name"]).to eq("#{moon_phase} Insight")
    end

    it 'uses the current date when no date is provided' do
      result = AstrologyService.recommended_spread

      today = Date.current
      zodiac = AstrologyService.current_zodiac_sign(today)
      moon_phase = AstrologyService.current_moon_phase(today)

      expect(result[:name]).to eq("#{zodiac[:name]} #{moon_phase} Spread")
    end
  end
end
