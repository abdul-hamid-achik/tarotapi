FactoryBot.define do
  factory :reading_session do
    association :user
    transient do
      spread_to_use { nil }
    end

    spread { spread_to_use || association(:spread) }
    question { Faker::Lorem.question }
    reading_date { Time.current }
    status { 'completed' }
    session_id { SecureRandom.uuid }

    # Use sequence to ensure uniqueness
    sequence(:name) { |n| "reading_#{n}_#{Time.current.to_i}_#{SecureRandom.hex(4)}" }

    trait :with_card_readings do
      # Don't override name if already set

      after(:create) do |reading_session|
        reading_session.spread.positions.each_with_index do |position, index|
          create(:card_reading,
            reading_session: reading_session,
            user: reading_session.user,
            position: index + 1,
            spread_position: position,
            tarot_card: create(:tarot_card)
          )
        end
      end
    end

    trait :completed do
      status { 'completed' }
    end

    trait :in_progress do
      status { 'in_progress' }
    end

    before(:create) do |reading_session|
      reading_session.user ||= create(:user)
    end
  end

  factory :reading do
    association :user
    transient do
      spread_to_use { nil }
    end

    spread { spread_to_use || association(:spread) }
    question { Faker::Lorem.question }
    reading_date { Time.current }
    status { 'completed' }
    session_id { SecureRandom.uuid }

    # Use sequence to ensure uniqueness
    sequence(:name) { |n| "reading_#{n}_#{Time.current.to_i}_#{SecureRandom.hex(4)}" }

    trait :with_card_readings do
      # Don't override name if already set

      after(:create) do |reading|
        reading.spread.positions.each_with_index do |position, index|
          create(:card_reading,
            reading: reading,
            user: reading.user,
            position: index + 1,
            spread_position: position,
            tarot_card: create(:tarot_card)
          )
        end
      end
    end

    trait :completed do
      status { 'completed' }
    end

    trait :in_progress do
      status { 'in_progress' }
    end

    before(:create) do |reading|
      reading.user ||= create(:user)
    end
  end
end
