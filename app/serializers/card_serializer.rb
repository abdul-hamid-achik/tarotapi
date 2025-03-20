class CardSerializer
  include JSONAPI::Serializer
  
  attributes :name, :arcana, :suit, :description, :rank, :symbols, :image_url
  
  attribute :image_url do |card|
    Rails.application.routes.url_helpers.rails_blob_url(card.image) if card.image.attached?
  end
end 