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

    trait :with_card_readings do
      after(:create) do |reading_session|
        reading_session.spread.positions.each_with_index do |position, index|
          create(:card_reading,
            reading_session: reading_session,
            user: reading_session.user,
            position: index + 1,
            card: create(:card)
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
end
