FactoryBot.define do
  factory :api_client do
    association :organization
    name { "Test API Client #{SecureRandom.hex(4)}" }

    transient do
      plaintext_secret { SecureRandom.hex(32) }
    end

    client_id { SecureRandom.hex(32) }
    client_secret { BCrypt::Password.create(plaintext_secret) }
    redirect_uri { "https://example.com/callback" }

    # Make the plaintext secret available via client.plaintext_secret
    after(:create) do |client, evaluator|
      client.define_singleton_method(:plaintext_secret) do
        evaluator.plaintext_secret
      end
    end
  end
end
