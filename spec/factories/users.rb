FactoryBot.define do
  factory :user do
    email { Faker::Internet.email }
    external_id { Faker::Internet.uuid }
    metadata { {} }
    password { "password123" }
    password_confirmation { "password123" }

    after(:build) do |user|
      user.identity_provider ||= IdentityProvider.registered
    end

    trait :anonymous do
      password { nil }
      password_confirmation { nil }
      
      after(:build) do |user|
        user.identity_provider = IdentityProvider.anonymous
      end
    end

    trait :agent do
      password { nil }
      password_confirmation { nil }
      
      after(:build) do |user|
        user.identity_provider = IdentityProvider.agent
      end
    end
  end
end
