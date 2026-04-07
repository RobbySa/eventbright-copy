module Orders
  class View
    def initialize(order)
      @order = order
    end

    def as_json(*)
      {
        id: @order.id,
        status: @order.status,
        total_cents: @order.total_cents,
        currency: @order.currency,
        placed_at: @order.placed_at,
        items: @order.order_items.map do |item|
          {
            ticket_type_id: item.ticket_type_id,
            quantity: item.quantity,
            unit_price_cents_snapshot: item.unit_price_cents_snapshot
          }
        end
      }
    end
  end
end