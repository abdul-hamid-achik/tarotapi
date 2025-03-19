FactoryBot.define do
  factory :identity_provider do
    provider { %w[google github].sample }
    uid { Faker::Internet.uuid }
    association :user
  end
end
