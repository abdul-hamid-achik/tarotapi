FactoryBot.define do
  factory :identity_provider do
    sequence(:name) { |n| "provider-#{n}" }
    provider_type { %w[oauth email anonymous].sample }
    settings { {} }
  end
end
