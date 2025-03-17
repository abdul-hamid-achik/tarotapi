class AstrologyService
  ZODIAC_SIGNS = [
    { name: "Aries", start_date: [3, 21], end_date: [4, 19], element: "Fire", ruling_planet: "Mars" },
    { name: "Taurus", start_date: [4, 20], end_date: [5, 20], element: "Earth", ruling_planet: "Venus" },
    { name: "Gemini", start_date: [5, 21], end_date: [6, 20], element: "Air", ruling_planet: "Mercury" },
    { name: "Cancer", start_date: [6, 21], end_date: [7, 22], element: "Water", ruling_planet: "Moon" },
    { name: "Leo", start_date: [7, 23], end_date: [8, 22], element: "Fire", ruling_planet: "Sun" },
    { name: "Virgo", start_date: [8, 23], end_date: [9, 22], element: "Earth", ruling_planet: "Mercury" },
    { name: "Libra", start_date: [9, 23], end_date: [10, 22], element: "Air", ruling_planet: "Venus" },
    { name: "Scorpio", start_date: [10, 23], end_date: [11, 21], element: "Water", ruling_planet: "Pluto" },
    { name: "Sagittarius", start_date: [11, 22], end_date: [12, 21], element: "Fire", ruling_planet: "Jupiter" },
    { name: "Capricorn", start_date: [12, 22], end_date: [1, 19], element: "Earth", ruling_planet: "Saturn" },
    { name: "Aquarius", start_date: [1, 20], end_date: [2, 18], element: "Air", ruling_planet: "Uranus" },
    { name: "Pisces", start_date: [2, 19], end_date: [3, 20], element: "Water", ruling_planet: "Neptune" }
  ]

  MOON_PHASES = [
    "New Moon", "Waxing Crescent", "First Quarter", "Waxing Gibbous", 
    "Full Moon", "Waning Gibbous", "Last Quarter", "Waning Crescent"
  ]

  SEASONAL_SPREADS = {
    spring: ["Growth Spread", "Renewal Spread", "Planting Seeds Spread"],
    summer: ["Abundance Spread", "Vitality Spread", "Manifestation Spread"],
    fall: ["Harvest Spread", "Release Spread", "Transformation Spread"],
    winter: ["Reflection Spread", "Inner Light Spread", "Hibernation Spread"]
  }

  class << self
    def current_zodiac_sign(date = Date.current)
      month = date.month
      day = date.day
      
      ZODIAC_SIGNS.find do |sign|
        start_month, start_day = sign[:start_date]
        end_month, end_day = sign[:end_date]
        
        if start_month == end_month
          month == start_month && day >= start_day && day <= end_day
        elsif start_month > end_month # Handles zodiac signs that span year boundary (e.g., Capricorn)
          (month == start_month && day >= start_day) || (month == end_month && day <= end_day)
        else
          (month == start_month && day >= start_day) || 
          (month > start_month && month < end_month) || 
          (month == end_month && day <= end_day)
        end
      end
    end

    def current_season(date = Date.current)
      month = date.month
      
      case month
      when 3, 4, 5
        :spring
      when 6, 7, 8
        :summer
      when 9, 10, 11
        :fall
      when 12, 1, 2
        :winter
      end
    end

    def current_moon_phase(date = Date.current)
      # This is a simplified calculation - for a real app, you might want to use an API
      days_since_new_moon = (date.jd - 2451550.1) % 29.53
      phase_index = (days_since_new_moon / 29.53 * 8).to_i % 8
      MOON_PHASES[phase_index]
    end

    def recommended_spread(date = Date.current)
      zodiac = current_zodiac_sign(date)
      season = current_season(date)
      moon_phase = current_moon_phase(date)
      
      # Create a spread based on current astrological conditions
      {
        name: "#{zodiac[:name]} #{moon_phase} Spread",
        description: "A spread aligned with #{zodiac[:name]} energy during the #{moon_phase} phase.",
        positions: [
          { "name" => "Current Energy", "description" => "The energy surrounding you right now" },
          { "name" => "#{zodiac[:element]} Influence", "description" => "How the #{zodiac[:element]} element is affecting you" },
          { "name" => "#{zodiac[:ruling_planet]} Guidance", "description" => "Guidance from #{zodiac[:name]}'s ruling planet, #{zodiac[:ruling_planet]}" },
          { "name" => "#{season.to_s.capitalize} Path", "description" => "Your path during this #{season.to_s} season" },
          { "name" => "#{moon_phase} Insight", "description" => "Insight revealed by the #{moon_phase}" }
        ],
        astrological_context: {
          zodiac_sign: zodiac[:name],
          element: zodiac[:element],
          ruling_planet: zodiac[:ruling_planet],
          season: season.to_s,
          moon_phase: moon_phase
        }
      }
    end
  end
end 