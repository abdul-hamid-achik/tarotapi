FactoryBot.define do
  factory :card_reading do
    reading_session
    tarot_card
    position { rand(1..10) }
    is_reversed { [true, false].sample }
    interpretation { Faker::Lorem.paragraph }
    user { reading_session&.user }
    spread_position { { name: 'position', description: 'description' } }
  end
end 