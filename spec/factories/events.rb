FactoryBot.define do
  factory :event do
    sequence(:name) { |n| "Event #{n}" }
    starts_at { 1.week.from_now }
    ends_at { 2.weeks.from_now }
  end
end
