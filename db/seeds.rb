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
require_relative '../lib/tarot_logger'

def load_json_data(filename)
  json_path = Rails.root.join("db", "seed_data", filename)
  JSON.parse(File.read(json_path))
end

# setup card images
TarotLogger.divine_ritual("database_seeding") do
  # Set up card images
  seed_data_dir = Rails.root.join("db", "seed_data", "cards")
  FileUtils.mkdir_p(seed_data_dir) unless Dir.exist?(seed_data_dir)

  # Check if we need to set up images
  if Dir.glob(File.join(seed_data_dir, "*.jpg")).count < 78
    TarotLogger.info("Setting up card images in seed_data...")

    # First check if we have a backup folder already
    backup_dir = Rails.root.join("card_images_backup")

    if Dir.exist?(backup_dir) && Dir.glob(File.join(backup_dir, "*.jpg")).count >= 78
      # Use images from backup if available
      TarotLogger.info("Found backup directory, moving images to seed_data...")
      FileUtils.cp(Dir.glob(File.join(backup_dir, "*.jpg")), seed_data_dir)
      TarotLogger.info("Moved images to seed_data")
    elsif Dir.exist?(Rails.root.join("public", "cards")) &&
          Dir.glob(File.join(Rails.root.join("public", "cards"), "*.jpg")).count >= 78
      # Use images from public/cards if available
      TarotLogger.info("Found public cards directory, moving images to seed_data...")
      FileUtils.cp(Dir.glob(File.join(Rails.root.join("public", "cards"), "*.jpg")), seed_data_dir)
      TarotLogger.info("Moved images to seed_data")

      # Backup the cards
      FileUtils.mkdir_p(backup_dir)
      FileUtils.cp(Dir.glob(File.join(Rails.root.join("public", "cards"), "*.jpg")), backup_dir)
      TarotLogger.info("Backed up public cards directory")
    end
  end

  # Create cards if they don't exist
  if Card.count == 0
    # Create Major Arcana
    major_arcana = [
      { name: "The Fool", number: 0, suit: "major", description: "New beginnings, innocence, spontaneity" },
      { name: "The Magician", number: 1, suit: "major", description: "Manifestation, resourcefulness, power" },
      { name: "The High Priestess", number: 2, suit: "major", description: "Intuition, sacred knowledge, divine feminine" },
      { name: "The Empress", number: 3, suit: "major", description: "Femininity, beauty, nature" },
      { name: "The Emperor", number: 4, suit: "major", description: "Authority, structure, control" },
      { name: "The Hierophant", number: 5, suit: "major", description: "Spiritual wisdom, religious beliefs, tradition" },
      { name: "The Lovers", number: 6, suit: "major", description: "Love, harmony, relationships" },
      { name: "The Chariot", number: 7, suit: "major", description: "Control, willpower, success" },
      { name: "Strength", number: 8, suit: "major", description: "Courage, inner strength, conviction" },
      { name: "The Hermit", number: 9, suit: "major", description: "Soul-searching, introspection, solitude" },
      { name: "Wheel of Fortune", number: 10, suit: "major", description: "Good luck, karma, destiny" },
      { name: "Justice", number: 11, suit: "major", description: "Justice, fairness, truth" },
      { name: "The Hanged Man", number: 12, suit: "major", description: "Surrender, letting go, sacrifice" },
      { name: "Death", number: 13, suit: "major", description: "Endings, change, transformation" },
      { name: "Temperance", number: 14, suit: "major", description: "Balance, moderation, patience" },
      { name: "The Devil", number: 15, suit: "major", description: "Shadow self, attachment, addiction" },
      { name: "The Tower", number: 16, suit: "major", description: "Sudden change, upheaval, chaos" },
      { name: "The Star", number: 17, suit: "major", description: "Hope, faith, purpose" },
      { name: "The Moon", number: 18, suit: "major", description: "Illusion, fear, anxiety" },
      { name: "The Sun", number: 19, suit: "major", description: "Positivity, fun, warmth" },
      { name: "Judgement", number: 20, suit: "major", description: "Judgement, rebirth, inner calling" },
      { name: "The World", number: 21, suit: "major", description: "Completion, accomplishment, travel" }
    ]

    # Create each major arcana card
    major_arcana.each do |card_info|
      Card.create!(card_info)
    end

    # Create Minor Arcana
    suits = [ "cups", "pentacles", "swords", "wands" ]

    suits.each do |suit|
      (1..10).each do |number|
        Card.create!(
          name: "#{number} of #{suit.capitalize}",
          number: number,
          suit: suit,
          description: "Minor Arcana #{suit} card"
        )
      end

      # Create court cards
      [ "Page", "Knight", "Queen", "King" ].each do |court|
        Card.create!(
          name: "#{court} of #{suit.capitalize}",
          number: case court
                  when "Page" then 11
                  when "Knight" then 12
                  when "Queen" then 13
                  when "King" then 14
                  end,
          suit: suit,
          description: "Minor Arcana #{suit} court card"
        )
      end
    end

    TarotLogger.info("Seeded card data", { count: Card.count })
  end

  # Create admin user
  admin_email = "admin@example.com"
  admin_password = "password"

  if defined?(User) && !User.find_by(email: admin_email)
    admin = User.new(
      email: admin_email,
      password: admin_password,
      password_confirmation: admin_password,
      admin: true
    )

    admin.save!
    TarotLogger.info("Created admin user", { email: admin.email })
  end

  # Create traditional spreads
  if defined?(Spread) && Spread.count == 0
    traditional_spreads = [
      { name: "Three Card", description: "Past, Present, Future", card_count: 3, layout: [
        { position: 0, name: "Past", x: 0, y: 0 },
        { position: 1, name: "Present", x: 1, y: 0 },
        { position: 2, name: "Future", x: 2, y: 0 }
      ].to_json },
      { name: "Celtic Cross", description: "Detailed 10-card spread", card_count: 10, layout: [
        { position: 0, name: "Present", x: 1, y: 1 },
        { position: 1, name: "Challenge", x: 1, y: 1, rotation: 90 },
        { position: 2, name: "Foundation", x: 1, y: 2 },
        { position: 3, name: "Recent Past", x: 0, y: 1 },
        { position: 4, name: "Potential", x: 1, y: 0 },
        { position: 5, name: "Near Future", x: 2, y: 1 },
        { position: 6, name: "Self", x: 3, y: 3 },
        { position: 7, name: "Environment", x: 3, y: 2 },
        { position: 8, name: "Hopes/Fears", x: 3, y: 1 },
        { position: 9, name: "Outcome", x: 3, y: 0 }
      ].to_json },
      { name: "Horseshoe", description: "7-card spread in horseshoe shape", card_count: 7, layout: [
        { position: 0, name: "Past", x: 0, y: 1 },
        { position: 1, name: "Present", x: 1, y: 0 },
        { position: 2, name: "Hidden Influences", x: 2, y: 0 },
        { position: 3, name: "Obstacles", x: 3, y: 0 },
        { position: 4, name: "External Influences", x: 4, y: 0 },
        { position: 5, name: "Advice", x: 5, y: 0 },
        { position: 6, name: "Outcome", x: 6, y: 1 }
      ].to_json },
      { name: "Single Card", description: "Simple one card reading", card_count: 1, layout: [
        { position: 0, name: "Card", x: 0, y: 0 }
      ].to_json }
    ]

    traditional_spreads.each do |spread_info|
      Spread.create!(spread_info)
    end

    TarotLogger.info("Seeded traditional spreads", { count: Spread.count })
  end

  # Create system spreads for each card
  TarotLogger.info("Seeding system spreads...")

  if defined?(Spread) && Spread.where(system: true).count == 0
    system_spreads = []

    Card.all.each do |card|
      system_spreads << Spread.create!(
        name: "#{card.name} Exploration",
        description: "Deep dive into the meaning of #{card.name}",
        system: true,
        card_count: 4,
        focus_card_id: card.id,
        layout: [
          { position: 0, name: "Focus Card: #{card.name}", x: 1, y: 1, fixed_card_id: card.id },
          { position: 1, name: "Light Aspect", x: 1, y: 0 },
          { position: 2, name: "Shadow Aspect", x: 0, y: 1 },
          { position: 3, name: "Lesson", x: 2, y: 1 },
          { position: 4, name: "Integration", x: 1, y: 2 }
        ].to_json
      )
    end

    TarotLogger.info("Created system spreads", { count: system_spreads.count })
  end

  # Load subscription plans
  begin
    load Rails.root.join('db', 'seeds', 'subscription_plans.rb')
  rescue => e
    TarotLogger.error("Error loading subscription plans", { error: e.message })
  end

  # Create reading quotas for users
  if defined?(ReadingQuota) && ReadingQuota.count == 0 && defined?(User)
    TarotLogger.info("Setting up reading quotas for existing users...")

    # Default limits for free users
    free_monthly_limit = ENV.fetch("FREE_TIER_READING_LIMIT", 5).to_i
    free_llm_calls_limit = ENV.fetch("FREE_TIER_LLM_LIMIT", 50).to_i

    # Create default quotas for all users without active subscriptions
    users_without_quotas = User.where(subscription_status: [ nil, "inactive" ])

    quotas_created = 0
    users_without_quotas.find_each do |user|
      # Skip if already has a quota
      next if user.reading_quota.present?

      # Create quota with free tier limits
      ReadingQuota.create!(
        user: user,
        monthly_limit: free_monthly_limit,
        readings_count: 0,
        last_reset_at: Time.current,
        next_reset_at: Time.current.end_of_month,
        llm_calls_limit: free_llm_calls_limit,
        llm_calls_count: 0
      )

      quotas_created += 1
    end

    TarotLogger.info("Reading quotas initialized for free users", { count: quotas_created })
  end

  # Summary of what was created
  TarotLogger.divine("Seeds completed!", {
    spreads: Spread.count,
    cards: Card.count,
    users: defined?(User) ? User.count : 0,
    reading_quotas: defined?(ReadingQuota) ? ReadingQuota.count : 0,
    subscription_plans: defined?(SubscriptionPlan) ? SubscriptionPlan.count : 0
  })
end

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

  # Only query subscription_status if the column exists
  if ActiveRecord::Base.connection.column_exists?(:users, :subscription_status)
    users_needing_quota = User.where(subscription_status: [ nil, "inactive" ])
  else
    users_needing_quota = User.all
  end

  users_needing_quota.find_each do |user|
    ReadingQuota.find_or_create_by(user_id: user.id) do |quota|
      quota.monthly_limit = default_limit
      quota.readings_this_month = 0
      quota.reset_date = reset_date
    end
  end

  puts "Reading quotas initialized for #{User.where(subscription_status: [ nil, "inactive" ]).count} free users"
end

# Load user credits system (must come after users and subscription plans)
load Rails.root.join('db', 'seeds', 'user_credits.rb')
