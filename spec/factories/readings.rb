FactoryBot.define do
  factory :reading do
    user
    spread
    question { "What does my future hold?" }
    status { "completed" }
    session_id { SecureRandom.uuid }
    name { nil } # Will be auto-generated
    reading_date { Time.current }
    astrological_context { { "zodiac_sign" => "Leo", "moon_phase" => "Full" } }

    trait :pending do
      status { "pending" }
    end

    trait :with_card_readings do
      after(:create) do |reading|
        create_list(:card_reading, 3, reading: reading)
      end
    end

    trait :without_spread do
      spread { nil }
    end

    trait :with_custom_name do
      name { "Custom Reading Name" }
    end
  end
end
