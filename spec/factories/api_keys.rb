FactoryBot.define do
  factory :api_key do
    name { "MyString" }
    token { "MyString" }
    expires_at { "2025-03-21 01:24:04" }
    user { nil }
    rate_limit { 1 }
    last_used_at { "2025-03-21 01:24:04" }
    description { "MyString" }
    active { false }
  end
end
