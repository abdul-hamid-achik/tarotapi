FactoryBot.define do
  factory :card_interpretation do
    card
    position_type { "upright" }
    meaning { "This card represents new beginnings and unlimited potential." }
    interpretation_type { "general" }
    version { "v1" }
    is_current_version { true }
    keywords { [ "beginnings", "potential", "opportunity" ] }
    associations { { "element" => "air", "planet" => "mercury" } }
    published_at { Time.current }

    trait :reversed do
      position_type { "reversed" }
      meaning { "In reverse, this card suggests missed opportunities or recklessness." }
    end

    trait :love do
      interpretation_type { "love" }
      meaning { "In a love reading, this card represents new relationships or renewed passion." }
    end

    trait :career do
      interpretation_type { "career" }
      meaning { "In a career reading, this card suggests new job opportunities or ventures." }
    end

    trait :previous_version do
      is_current_version { false }
      next_version_id { nil }
    end

    trait :with_version_history do
      after(:create) do |interpretation|
        previous_version = create(:card_interpretation, :previous_version,
          card: interpretation.card,
          position_type: interpretation.position_type,
          interpretation_type: interpretation.interpretation_type,
          version: "v1",
          published_at: 1.month.ago
        )

        interpretation.update(
          previous_version_id: previous_version.id,
          version: "v2"
        )

        previous_version.update(next_version_id: interpretation.id)
      end
    end
  end
end
