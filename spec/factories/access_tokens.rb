FactoryBot.define do
  factory :access_token do
    association :authorization
    token { SecureRandom.hex(32) }
    refresh_token { SecureRandom.hex(32) }
    scope { "read write" }
    expires_at { 2.hours.from_now }
    last_used_at { nil }

    trait :expired do
      expires_at { 1.day.ago }
    end

    trait :used do
      last_used_at { 1.hour.ago }
    end
  end
end
