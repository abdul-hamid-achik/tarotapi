class CardReadingSerializer
  include JSONAPI::Serializer

  attributes :position, :notes, :is_reversed, :created_at, :updated_at

  belongs_to :user
  belongs_to :tarot_card
  belongs_to :spread, optional: true
  belongs_to :reading_session

  attribute :card_name do |reading|
    reading.tarot_card.name
  end

  attribute :card_image do |reading|
    reading.tarot_card.image_url
  end
end
