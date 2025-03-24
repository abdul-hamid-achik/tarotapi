FactoryBot.define do
  factory :organization do
    name { "Test Organization #{SecureRandom.hex(4)}" }
    plan { "basic" }
    billing_email { "billing@example.com" }
    status { "active" }
    features { '{"max_members":20,"api_rate_limit":1000,"custom_spreads":true,"white_label":true,"priority_support":false}' }
    quotas { '{"daily_readings":1000,"monthly_api_calls":100000,"concurrent_sessions":50}' }

    trait :pro do
      plan { "pro" }
      features { '{"max_members":100,"api_rate_limit":10000,"custom_spreads":true,"white_label":true,"priority_support":true}' }
      quotas { '{"daily_readings":10000,"monthly_api_calls":1000000,"concurrent_sessions":250}' }
    end

    trait :free do
      plan { "free" }
      features { '{"max_members":5,"api_rate_limit":100,"custom_spreads":false,"white_label":false,"priority_support":false}' }
      quotas { '{"daily_readings":100,"monthly_api_calls":10000,"concurrent_sessions":10}' }
    end

    trait :enterprise do
      plan { "enterprise" }
      features { '{"max_members":100,"api_rate_limit":10000,"custom_spreads":true,"white_label":true,"priority_support":true}' }
      quotas { '{"daily_readings":10000,"monthly_api_calls":1000000,"concurrent_sessions":250}' }
    end

    trait :suspended do
      status { "suspended" }
    end

    trait :cancelled do
      status { "cancelled" }
    end
  end
end
