class ReadingSerializer
  include JSONAPI::Serializer

  attributes :session_id, :status, :question, :interpretation, :reading_date, :astrological_context, :birth_date, :name

  belongs_to :user
  belongs_to :spread, if: Proc.new { |record| record.spread.present? }
  has_many :card_readings

  attribute :spread_name do |reading|
    reading.spread&.name || reading.astrological_context&.dig("zodiac_sign")&.concat(" Spread")
  end

  attribute :card_count do |reading|
    reading.card_readings.count
  end

  attribute :zodiac_sign do |reading|
    reading.astrological_context&.dig("zodiac_sign")
  end

  attribute :moon_phase do |reading|
    reading.astrological_context&.dig("moon_phase")
  end

  attribute :element do |reading|
    reading.astrological_context&.dig("element")
  end

  attribute :season do |reading|
    reading.astrological_context&.dig("season")&.capitalize
  end

  attribute :life_path_number do |reading|
    reading.birth_date.present? ? NumerologyService.calculate_life_path_number(reading.birth_date) : nil
  end

  attribute :name_number do |reading|
    reading.name.present? ? NumerologyService.calculate_name_number(reading.name) : nil
  end
end
