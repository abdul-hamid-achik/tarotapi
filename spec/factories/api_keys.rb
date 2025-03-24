FactoryBot.define do
  factory :api_key do
    name { "Test API Key" }
    key { SecureRandom.hex(24) }
    expires_at { 1.year.from_now }
    association :user
    rate_limit { 100 }
    last_used_at { nil }
    description { "API key for testing" }
    active { true }
  end
end
