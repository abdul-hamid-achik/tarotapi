FactoryBot.define do
  factory :card do
    name { Faker::Ancient.god }
    arcana { %w[major minor].sample }
    description { Faker::Lorem.paragraph }
    rank { arcana == 'major' ? (0..21).to_a.sample.to_s : nil }
    suit { arcana == 'minor' ? %w[wands cups swords pentacles].sample : nil }
    symbols { Faker::Lorem.words(number: 3).join(', ') }
    image_url { Faker::Internet.url }
  end

  # Define tarot_card as an alias to card for backwards compatibility
  factory :tarot_card, parent: :card
end
