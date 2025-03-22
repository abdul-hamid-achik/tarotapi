FactoryBot.define do
  factory :subscription do
    association :user
    status { 'active' }
    plan_name { 'basic' }
    current_period_end { 1.month.from_now }
    ends_at { nil }
    stripe_id { "sub_#{SecureRandom.hex(10)}" }
    client_secret { "cs_#{SecureRandom.hex(10)}" }
  end
end
