puts "Cleaning database..."
OrderItem.destroy_all
Order.destroy_all
TicketType.destroy_all
Event.destroy_all

# ----------------------------------------------------------------
# Events
# ----------------------------------------------------------------
puts "Creating events..."

jazz_night = Event.create!(
  name:      "Jazz Night at the Rooftop",
  starts_at: 2.weeks.from_now.change(hour: 19, min: 0),
  ends_at:   2.weeks.from_now.change(hour: 23, min: 0)
)

comedy_show = Event.create!(
  name:      "Stand-Up Showcase",
  starts_at: 3.weeks.from_now.change(hour: 20, min: 0),
  ends_at:   3.weeks.from_now.change(hour: 22, min: 30)
)

tech_conf = Event.create!(
  name:      "LocalDev Conference 2026",
  starts_at: 1.month.from_now.change(hour: 9, min: 0),
  ends_at:   1.month.from_now.change(hour: 18, min: 0)
)

draft_event = Event.create!(
  name:      "Secret Pop-Up (Draft)",
  starts_at: 2.months.from_now.change(hour: 18, min: 0),
  ends_at:   2.months.from_now.change(hour: 21, min: 0)
)

old_event = Event.create!(
  name:      "Concert from the Past",
  starts_at: 2.months.ago.change(hour: 18, min: 0),
  ends_at:   2.months.ago.change(hour: 21, min: 0)
)

# ----------------------------------------------------------------
# Ticket Types
# ----------------------------------------------------------------
puts "Creating ticket types..."

# Jazz Night
jazz_ga = TicketType.create!(
  event:          jazz_night,
  name:           "General Admission",
  price_cents:    2500,
  currency:       "USD",
  total_quantity: 100,
  sold_quantity:  0
)

jazz_vip = TicketType.create!(
  event:          jazz_night,
  name:           "VIP",
  price_cents:    7500,
  currency:       "USD",
  total_quantity: 20,
  sold_quantity:  0
)

# Comedy Show
comedy_standard = TicketType.create!(
  event:          comedy_show,
  name:           "Standard",
  price_cents:    1500,
  currency:       "USD",
  total_quantity: 80,
  sold_quantity:  0
)

comedy_front_row = TicketType.create!(
  event:          comedy_show,
  name:           "Front Row",
  price_cents:    3500,
  currency:       "USD",
  total_quantity: 10,
  sold_quantity:  0
)

# Tech Conference
tech_early_bird = TicketType.create!(
  event:          tech_conf,
  name:           "Early Bird",
  price_cents:    4900,
  currency:       "USD",
  total_quantity: 30,
  sold_quantity:  0
)

tech_standard = TicketType.create!(
  event:          tech_conf,
  name:           "Standard",
  price_cents:    9900,
  currency:       "USD",
  total_quantity: 150,
  sold_quantity:  0
)

tech_workshop = TicketType.create!(
  event:          tech_conf,
  name:           "Workshop Add-on",
  price_cents:    2000,
  currency:       "USD",
  total_quantity: 40,
  sold_quantity:  0
)

# ----------------------------------------------------------------
# Customers
# ----------------------------------------------------------------
puts "Creating customers..."

alice = "alice@example.com"
bob   = "bob@example.com"
carol = "carol@example.com"

# ----------------------------------------------------------------
# Sample Orders (via Orders::Place service so inventory stays in sync)
# ----------------------------------------------------------------
puts "Placing sample orders..."

# Alice buys 2x GA + 1x VIP for Jazz Night
result = Orders::Place.new(
  email: alice,
  items: [
    { ticket_type_id: jazz_ga.id,  quantity: 2 },
    { ticket_type_id: jazz_vip.id, quantity: 1 }
  ]
).call
raise "Seed failed: #{result[:error]}" unless result[:success?]
puts "  ✓ Alice placed order ##{result[:order].id} (Jazz Night — GA x2 + VIP x1)"

# Bob buys 2x Standard for Comedy Show
result = Orders::Place.new(
  email: bob,
  items: [
    { ticket_type_id: comedy_standard.id, quantity: 2 }
  ]
).call
raise "Seed failed: #{result[:error]}" unless result[:success?]
puts "  ✓ Bob placed order ##{result[:order].id} (Comedy Show — Standard x2)"

# Carol buys Early Bird + Workshop for Tech Conf
result = Orders::Place.new(
  email: carol,
  items: [
    { ticket_type_id: tech_early_bird.id, quantity: 1 },
    { ticket_type_id: tech_workshop.id,   quantity: 1 }
  ]
).call
raise "Seed failed: #{result[:error]}" unless result[:success?]
puts "  ✓ Carol placed order ##{result[:order].id} (Tech Conf — Early Bird + Workshop)"

# Bob also grabs a front row seat for Comedy Show
result = Orders::Place.new(
  email: bob,
  items: [
    { ticket_type_id: comedy_front_row.id, quantity: 1 }
  ]
).call
raise "Seed failed: #{result[:error]}" unless result[:success?]
puts "  ✓ Bob placed order ##{result[:order].id} (Comedy Show — Front Row x1)"

# ----------------------------------------------------------------
# Summary
# ----------------------------------------------------------------
puts ""
puts "Seed complete!"
puts "  Events:       #{Event.count}"
puts "  Ticket types: #{TicketType.count}"
puts "  Orders:       #{Order.count}"
puts "  Order items:  #{OrderItem.count}"
