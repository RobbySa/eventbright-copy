# app/serializers/order_serializer.rb
class OrderSerializer
  def initialize(order)
    @order = order
  end

  def as_json(*)
    {
      id:          @order.id,
      status:      @order.status,
      currency:    @order.currency,
      total_cents: @order.total_cents,
      total:       format_money(@order.total_cents, @order.currency),
      placed_at:   @order.placed_at&.iso8601,
      items:       @order.order_items.map { |i| serialize_item(i) }
    }
  end

  private

  def serialize_item(item)
    {
      id:               item.id,
      ticket_type_id:   item.ticket_type_id,
      ticket_type_name: item.ticket_type.name,
      quantity:         item.quantity,
      unit_price_cents: item.unit_price_cents_snapshot,
      unit_price:       format_money(item.unit_price_cents_snapshot, @order.currency)
    }
  end

  def format_money(cents, currency)
    return nil if cents.nil?
    { amount: (cents / 100.0).round(2), currency: currency }
  end
end
