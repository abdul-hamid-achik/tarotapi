FactoryBot.define do
  factory :membership do
    association :user
    association :organization
    role { "member" }
    status { "active" }

    trait :admin do
      role { "admin" }
    end

    trait :invited do
      status { "invited" }
    end

    trait :suspended do
      status { "suspended" }
    end
  end
end
