FactoryBot.define do
  factory :ticket_type do
    association :event
    sequence(:name) { |n| "Ticket Type #{n}" }
    price_cents     { 1000 }
    currency        { 'USD' }
    total_quantity  { 100 }
    sold_quantity   { 0 }
  end
end
