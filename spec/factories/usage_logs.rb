FactoryBot.define do
  factory :usage_log do
    organization
    user
    metric_type { "api_call" }
    recorded_at { Time.current }
    metadata { {
      endpoint: "/api/v1/readings",
      status: "200",
      response_time: 150
    } }

    trait :api_call do
      metric_type { "api_call" }
      metadata { {
        endpoint: "/api/v1/readings",
        status: "200",
        response_time: 150
      } }
    end

    trait :reading do
      metric_type { "reading" }
      metadata { {} }
    end

    trait :session do
      metric_type { "session" }
      metadata { {
        concurrent_count: 5
      } }
    end

    trait :error do
      metric_type { "error" }
      metadata { {
        error_message: "Internal server error",
        endpoint: "/api/v1/readings"
      } }
    end

    trait :failed do
      metadata { {
        endpoint: "/api/v1/readings",
        status: "500",
        response_time: 350,
        error_message: "Database connection error"
      } }
    end

    trait :without_user do
      user { nil }
    end
  end
end
