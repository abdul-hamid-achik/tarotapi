# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

require "json"
require "fileutils"

def load_json_data(filename)
  json_path = Rails.root.join("db", "seed_data", filename)
  JSON.parse(File.read(json_path))
end

# setup card images
puts 'setting up card images in seed_data...'
cards_dir = Rails.root.join('db', 'seed_data', 'cards')
FileUtils.mkdir_p(cards_dir)

# if we have a backup in public, move it to seed_data
backup_dir = Rails.root.join('public', 'cards_backup')
if Dir.exist?(backup_dir)
  puts 'found backup directory, moving images to seed_data...'
  FileUtils.cp_r(Dir[File.join(backup_dir, '*')], cards_dir)
  puts 'moved images to seed_data'
end

# if we still have images in public/cards, move those too
public_cards = Rails.root.join('public', 'cards')
if Dir.exist?(public_cards)
  puts 'found public cards directory, moving images to seed_data...'
  FileUtils.cp_r(Dir[File.join(public_cards, '*')], cards_dir)
  puts 'moved images to seed_data'

  # backup and remove the public directory
  FileUtils.mv(public_cards, backup_dir) unless Dir.exist?(backup_dir)
  puts 'backed up public cards directory'
end

# seed tarot cards
tarot_data = load_json_data("cards.json")
tarot_data["cards"].each do |card_data|
  # Skip cards without a name
  next unless card_data["name"].present?

  # Clean up the filename - remove spaces and downcase
  file_name = card_data["name"].gsub(/\s+/, '').downcase

  # Create or update the card
  card = Card.find_or_create_by!(name: card_data["name"]) do |c|
    c.arcana = card_data["arcana"]
    c.suit = card_data["suit"]
    c.description = card_data["description"]
    c.rank = card_data["rank"].to_s if card_data["rank"].present?
    c.symbols = card_data["symbols"]
    # Add default image_url if needed - look for PNG first, then JPG
    if card_data["image_url"].blank?
      if card_data["arcana"].downcase == "major"
        c.image_url = "cards/#{file_name}.png" 
      else
        c.image_url = "cards/#{card_data['arcana'].downcase}_#{card_data['suit']}_#{card_data['rank']}.png"
      end
    else
      c.image_url = card_data["image_url"]
    end
  end
  
  # Try to attach the image if it's not already attached
  unless card.image.attached?
    card.attach_image_from_file_system
  end
end

puts "seeded #{Card.count} cards"

# create default admin user for testing
admin = User.find_or_create_by!(email: "admin@tarotapi.cards") do |user|
  user.name = 'admin'
  user.admin = true
  user.password = 'changeme'
  user.password_confirmation = 'changeme'
end

puts "created admin user"

# create admin user for development
if Rails.env.development?
  admin = User.find_or_create_by!(email: 'admin@tarotapi.cards') do |u|
    u.name = 'admin'
    u.admin = true
    u.password = 'password123'
    u.password_confirmation = 'password123'
  end

  puts "admin user created: #{admin.email}"
end

# seed system spreads (traditional layouts)
spread_data = load_json_data("spreads.json")
spread_data["spreads"].each do |spread_data|
  Spread.find_or_create_by!(name: spread_data["name"]) do |spread|
    spread.description = spread_data["description"]
    spread.positions = spread_data["positions"]
    spread.num_cards = spread_data["positions"].size
    spread.is_public = true # system spreads are always public
    spread.is_system = true
    spread.user = admin
  end
end

puts "seeded #{Spread.count} traditional spreads"

# seed system spreads
puts 'seeding system spreads...'
system_spreads = SpreadService.system_spreads
puts "created #{system_spreads.count} system spreads"

# create basic spreads
spreads = [
  {
    name: 'three card',
    description: 'a simple three card spread for quick readings',
    num_cards: 3,
    positions: [
      { name: 'past', description: 'influences from the past' },
      { name: 'present', description: 'current situation' },
      { name: 'future', description: 'likely outcome' }
    ]
  },
  {
    name: 'celtic cross',
    description: 'a detailed spread that gives insight into many aspects of a situation',
    num_cards: 10,
    positions: [
      { name: 'present', description: 'current situation' },
      { name: 'challenge', description: 'immediate challenge' },
      { name: 'past', description: 'recent past influences' },
      { name: 'future', description: 'approaching influences' },
      { name: 'above', description: 'conscious thoughts and goals' },
      { name: 'below', description: 'subconscious influences' },
      { name: 'advice', description: 'recommended approach' },
      { name: 'external influence', description: 'environmental factors' },
      { name: 'hopes & fears', description: 'your hopes and fears' },
      { name: 'outcome', description: 'final outcome' }
    ]
  },
  {
    name: 'horseshoe',
    description: 'a seven card spread in the shape of a horseshoe for good luck',
    num_cards: 7,
    positions: [
      { name: 'past', description: 'recent past influences' },
      { name: 'present', description: 'current situation' },
      { name: 'hidden influences', description: 'unseen forces at work' },
      { name: 'obstacles', description: 'challenges to overcome' },
      { name: 'external influences', description: 'outside factors affecting you' },
      { name: 'advice', description: 'guidance on your path' },
      { name: 'outcome', description: 'most likely outcome' }
    ]
  }
]

# Get the admin user reference to associate with the spreads
admin_user = User.find_by(email: 'admin@tarotapi.cards')
unless admin_user
  admin_user = User.create!(
    email: 'admin@tarotapi.cards',
    name: 'admin',
    admin: true,
    password: 'password123',
    password_confirmation: 'password123'
  )
end

spreads.each do |spread|
  Spread.find_or_create_by!(name: spread[:name]) do |s|
    s.description = spread[:description]
    s.num_cards = spread[:num_cards]
    s.positions = spread[:positions]
    s.user = admin_user
    s.is_public = true
    s.is_system = true
  end
end

# create major arcana cards
major_arcana = [
  {
    name: 'the fool',
    arcana: 'major',
    rank: '0',
    description: 'new beginnings, optimism, trust in life',
    symbols: 'beginnings, innocence, spontaneity, a free spirit',
    image_url: '/images/cards/ar00.jpg'
  },
  {
    name: 'the magician',
    arcana: 'major',
    rank: '1',
    description: 'manifestation, resourcefulness, power, inspired action',
    symbols: 'manifestation, resourcefulness, power, inspired action',
    image_url: '/images/cards/ar01.jpg'
  },
  {
    name: 'the high priestess',
    arcana: 'major',
    rank: '2',
    description: 'intuition, sacred knowledge, divine feminine, the subconscious mind',
    symbols: 'intuition, sacred knowledge, divine feminine, the subconscious mind',
    image_url: '/images/cards/ar02.jpg'
  }
  # complete with all other major arcana cards
]

major_arcana.each do |card|
  Card.find_or_create_by!(name: card[:name]) do |c|
    c.arcana = card[:arcana]
    c.rank = card[:rank]
    c.description = card[:description]
    c.symbols = card[:symbols]
    c.image_url = card[:image_url]
  end
end

# create minor arcana cards for each suit
suits = [ 'wands', 'cups', 'swords', 'pentacles' ]
values = [ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14 ]
court_cards = { 11 => 'page', 12 => 'knight', 13 => 'queen', 14 => 'king' }

puts "seeds completed! created:"
puts "  - #{Spread.count} spreads"
puts "  - #{Card.count} cards"
puts "  - #{User.count} users"

# Load subscription plans
load Rails.root.join('db', 'seeds', 'subscription_plans.rb')

# Initialize reading quotas for existing users
puts "Setting up reading quotas for existing users..."

if ActiveRecord::Base.connection.table_exists?("reading_quotas")
  default_limit = ENV.fetch("DEFAULT_FREE_TIER_LIMIT", 100).to_i
  reset_date = Date.today.end_of_month + 1.day
  
  User.where(subscription_status: [nil, "inactive"]).find_each do |user|
    ReadingQuota.find_or_create_by(user_id: user.id) do |quota|
      quota.monthly_limit = default_limit
      quota.readings_this_month = 0
      quota.reset_date = reset_date
    end
  end
  
  puts "Reading quotas initialized for #{User.where(subscription_status: [nil, "inactive"]).count} free users"
end
