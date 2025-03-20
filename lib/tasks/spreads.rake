namespace :spreads do
  desc "seed spreads"
  task seed_spreads: :environment do
    puts "seeding spreads..."

    # Only seed if no spreads exist
    if Spread.count.zero?
      spreads = [
        {
          name: "three card spread",
          description: "A simple three card spread representing past, present, and future",
          num_cards: 3,
          positions: [
            { name: "past", description: "Influences from the past affecting the situation" },
            { name: "present", description: "Current energy and circumstances" },
            { name: "future", description: "Potential outcome or future development" }
          ]
        },
        {
          name: "celtic cross",
          description: "A comprehensive 10-card spread for deep insights into a situation",
          num_cards: 10,
          positions: [
            { name: "present", description: "The present situation or influence" },
            { name: "challenge", description: "The immediate challenge or obstacle" },
            { name: "foundation", description: "The basis of the situation" },
            { name: "past", description: "Recent past events or influences" },
            { name: "crown", description: "Potential outcome or goal" },
            { name: "future", description: "The immediate future" },
            { name: "self", description: "Your attitude or position" },
            { name: "environment", description: "External influences" },
            { name: "hopes/fears", description: "Your hopes and/or fears" },
            { name: "outcome", description: "The final outcome" }
          ]
        },
        {
          name: "relationship spread",
          description: "A five card spread for insights into relationships",
          num_cards: 5,
          positions: [
            { name: "you", description: "Your role in the relationship" },
            { name: "partner", description: "Your partner's role in the relationship" },
            { name: "connection", description: "The connection between you" },
            { name: "challenge", description: "The challenge in your relationship" },
            { name: "outcome", description: "Potential outcome of the relationship" }
          ]
        }
      ]

      # Create admin user for spread ownership
      admin = User.find_by(email: "admin@tarotapi.cards") || User.create!(
        email: "admin@tarotapi.cards",
        name: "admin",
        admin: true,
        password: "password123",
        password_confirmation: "password123"
      )

      # Create the spreads
      spreads.each do |spread_data|
        Spread.create!(
          name: spread_data[:name],
          description: spread_data[:description],
          num_cards: spread_data[:num_cards],
          positions: spread_data[:positions],
          user_id: admin.id,
          is_public: true,
          is_system: true
        )
      end

      puts "created #{Spread.count} spreads"
    else
      puts "spreads already exist, skipping"
    end
  end
end 