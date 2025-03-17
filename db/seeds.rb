# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

require "json"

def load_json_data(filename)
  json_path = Rails.root.join("db", "seed_data", filename)
  JSON.parse(File.read(json_path))
end

def attach_card_image(card)
  image_path = Rails.root.join("public", "cards", "#{card.name.downcase.gsub(/\s+/, '_')}.jpg")
  return unless File.exist?(image_path)
  
  card.image.attach(
    io: File.open(image_path),
    filename: File.basename(image_path),
    content_type: "image/jpeg"
  )
end

# seed tarot cards
tarot_data = load_json_data("cards.json")
tarot_data["cards"].each do |card_data|
  card = TarotCard.find_or_create_by!(name: card_data["name"]) do |c|
    c.arcana = card_data["arcana"]
    c.suit = card_data["suit"]
    c.description = card_data["description"]
    c.rank = card_data["rank"]
    c.symbols = card_data["symbols"]
  end
  
  attach_card_image(card)
end

puts "seeded #{TarotCard.count} tarot cards"

# seed system spreads (traditional layouts)
spread_data = load_json_data("spreads.json")
spread_data["spreads"].each do |spread_data|
  Spread.find_or_create_by!(name: spread_data["name"]) do |spread|
    spread.description = spread_data["description"]
    spread.positions = spread_data["positions"]
    spread.is_public = true # system spreads are always public
  end
end

puts "seeded #{Spread.count} traditional spreads"

# create default admin user for testing
admin = User.find_or_create_by!(email: "admin@example.com") do |user|
  user.password = "password123"
  user.password_confirmation = "password123"
  user.admin = true
end

puts "created admin user"
