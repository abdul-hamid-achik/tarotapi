class TarotCardSerializer
  include FastJsonapi::ObjectSerializer

  attributes :name, :arcana, :description, :rank, :suit, :created_at, :updated_at

  attribute :image_url do |object|
    object.image.attached? ? Rails.application.routes.url_helpers.url_for(object.image) : nil
  end

  has_many :card_readings
end
