class TarotCardSerializer
  include JSONAPI::Serializer
  
  attributes :name, :arcana, :description, :rank, :symbols, :image_url, :created_at, :updated_at
  
  has_many :card_readings
end 