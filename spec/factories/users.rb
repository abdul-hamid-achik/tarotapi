FactoryBot.define do
  factory :user do
    email { Faker::Internet.email }
    external_id { Faker::Internet.uuid }
    metadata { {} }

    after(:build) do |user|
      user.identity_provider ||= IdentityProvider.registered
    end

    trait :anonymous do
      after(:build) do |user|
        user.identity_provider = IdentityProvider.anonymous
      end
    end

    trait :agent do
      after(:build) do |user|
        user.identity_provider = IdentityProvider.agent
      end
    end
  end
end
