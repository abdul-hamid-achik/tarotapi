class SpreadSerializer
  include JSONAPI::Serializer

  attributes :name, :description, :positions, :is_public, :created_at, :updated_at

  belongs_to :user
  has_many :card_readings

  attribute :position_count do |spread|
    spread.positions.size
  end

  attribute :zodiac_sign do |spread|
    spread.astrological_context&.dig("zodiac_sign")
  end

  attribute :moon_phase do |spread|
    spread.astrological_context&.dig("moon_phase")
  end

  attribute :element do |spread|
    spread.astrological_context&.dig("element")
  end

  attribute :season do |spread|
    spread.astrological_context&.dig("season")&.capitalize
  end
end
