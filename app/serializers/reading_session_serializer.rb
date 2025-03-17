class ReadingSessionSerializer
  include JSONAPI::Serializer
  
  attributes :session_id, :status, :question, :interpretation, :reading_date, :astrological_context, :birth_date, :name
  
  belongs_to :user
  belongs_to :spread, if: Proc.new { |record| record.spread.present? }
  has_many :card_readings
  
  attribute :spread_name do |session|
    session.spread&.name || session.astrological_context&.dig("zodiac_sign")&.concat(" Spread")
  end
  
  attribute :card_count do |session|
    session.card_readings.count
  end
  
  attribute :zodiac_sign do |session|
    session.astrological_context&.dig("zodiac_sign")
  end
  
  attribute :moon_phase do |session|
    session.astrological_context&.dig("moon_phase")
  end
  
  attribute :element do |session|
    session.astrological_context&.dig("element")
  end
  
  attribute :season do |session|
    session.astrological_context&.dig("season")&.capitalize
  end
  
  attribute :life_path_number do |session|
    session.birth_date.present? ? NumerologyService.calculate_life_path_number(session.birth_date) : nil
  end
  
  attribute :name_number do |session|
    session.name.present? ? NumerologyService.calculate_name_number(session.name) : nil
  end
end 