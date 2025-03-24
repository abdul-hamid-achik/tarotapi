FactoryBot.define do
  factory :authorization do
    association :user
    client_id { SecureRandom.hex(32) }
    code { SecureRandom.hex(16) }
    scope { "read write" }
    expires_at { 10.minutes.from_now }

    trait :expired do
      expires_at { 1.day.ago }
    end
  end
end
