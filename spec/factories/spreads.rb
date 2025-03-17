FactoryBot.define do
  factory :spread do
    sequence(:name) { |n| "spread-#{SecureRandom.hex(4)}-#{n}" }
    description { Faker::Lorem.paragraph }
    positions { [{ name: 'past', description: 'past influences' }, { name: 'present', description: 'current situation' }] }
    is_public { true }
    user
  end
end 