namespace :cards do
  desc "seed cards from json data"
  task seed_cards: :environment do
    if Card.count.zero?
      puts "seeding cards from json data..."
      
      # Major Arcana (0-21)
      major_arcana = [
        { name: "the fool", number: 0, arcana: "major", suit: nil, meaning_upright: "Beginnings, innocence, spontaneity, a free spirit", meaning_reversed: "Holding back, recklessness, risk-taking" },
        { name: "the magician", number: 1, arcana: "major", suit: nil, meaning_upright: "Manifestation, resourcefulness, power, inspired action", meaning_reversed: "Manipulation, poor planning, untapped talents" },
        { name: "the high priestess", number: 2, arcana: "major", suit: nil, meaning_upright: "Intuition, sacred knowledge, divine feminine, the subconscious mind", meaning_reversed: "Secrets, disconnected from intuition, withdrawal and silence" },
        # Add other major arcana cards
      ]

      # Minor Arcana - Wands (1-10, Page, Knight, Queen, King)
      wands = [
        { name: "ace of wands", number: 1, arcana: "minor", suit: "wands", meaning_upright: "Creation, willpower, inspiration, desire", meaning_reversed: "Lack of energy, lack of passion, boredom" },
        { name: "two of wands", number: 2, arcana: "minor", suit: "wands", meaning_upright: "Planning, making decisions, leaving home", meaning_reversed: "Fear of change, playing it safe, bad planning" },
        # Add other wands cards
      ]

      # Minor Arcana - Cups (1-10, Page, Knight, Queen, King)
      cups = [
        { name: "ace of cups", number: 1, arcana: "minor", suit: "cups", meaning_upright: "Love, new feelings, emotional awakening", meaning_reversed: "Emotional loss, blocked creativity, emptiness" },
        { name: "two of cups", number: 2, arcana: "minor", suit: "cups", meaning_upright: "Unity, partnership, connection", meaning_reversed: "Disconnection, misalignment, imbalance" },
        # Add other cups cards
      ]

      # Minor Arcana - Swords (1-10, Page, Knight, Queen, King)
      swords = [
        { name: "ace of swords", number: 1, arcana: "minor", suit: "swords", meaning_upright: "Breakthrough, clarity, sharp mind", meaning_reversed: "Confusion, brutality, chaos" },
        { name: "two of swords", number: 2, arcana: "minor", suit: "swords", meaning_upright: "Difficult choices, indecision, stalemate", meaning_reversed: "Lesser of two evils, no win scenarios, confusion" },
        # Add other swords cards
      ]

      # Minor Arcana - Pentacles (1-10, Page, Knight, Queen, King)
      pentacles = [
        { name: "ace of pentacles", number: 1, arcana: "minor", suit: "pentacles", meaning_upright: "New financial opportunity, prosperity, abundance", meaning_reversed: "Missed opportunity, scarcity, deficiency" },
        { name: "two of pentacles", number: 2, arcana: "minor", suit: "pentacles", meaning_upright: "Balance, prioritization, adaptation", meaning_reversed: "Imbalance, disorganization, overwhelmed" },
        # Add other pentacles cards
      ]

      # Combine all cards
      all_cards = major_arcana + wands + cups + swords + pentacles

      # Create the cards in the database
      all_cards.each do |card|
        Card.create!(
          name: card[:name],
          number: card[:number],
          arcana: card[:arcana],
          suit: card[:suit],
          meaning_upright: card[:meaning_upright],
          meaning_reversed: card[:meaning_reversed]
        )
      end

      puts "created #{Card.count} cards"
    else
      puts "cards already exist, skipping"
    end
  end

  desc "seed all card data"
  task seed_all: :environment do
    Rake::Task["cards:seed_cards"].invoke
    Rake::Task["spreads:seed_spreads"].invoke
  end
end 