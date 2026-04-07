# app/serializers/event_serializer.rb
class EventSerializer
  def initialize(event)
    @event = event
  end

  def as_json(*)
    {
      id:           @event.id,
      name:         @event.name,
      starts_at:    @event.starts_at&.iso8601,
      ends_at:      @event.ends_at&.iso8601,
      ticket_types: @event.ticket_types.map { |tt| serialize_ticket_type(tt).as_json }
    }
  end

  private

  def serialize_ticket_type(ticket_type)
    {
      ticket_type_id:   ticket_type.id,
      ticket_type_name: ticket_type.name,
      total_quantity:   ticket_type.total_quantity,
      sold_quantity:    ticket_type.sold_quantity,
      price_cents:      ticket_type.price_cents,
      unit_price:       format_money(ticket_type.price_cents, ticket_type.currency)
    }
  end

  def format_money(cents, currency)
    return nil if cents.nil?
    { amount: (cents / 100.0).round(2), currency: currency }
  end
end
