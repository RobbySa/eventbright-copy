module Orders
  class Place
    def initialize(email:, items:)
      # items: [{ ticket_type_id: 1, quantity: 2 }, ...]
      @items = items
      @email = email.to_s.downcase.strip
    end

    def call
      order = nil

      return { success?: false, order: nil, error: "No items provided" } if @items.empty?

      ActiveRecord::Base.transaction do
        ticket_types = lock_ticket_types!
        validate_availability!(ticket_types)
        order = build_order(ticket_types)
        decrement_inventory!(ticket_types)
      end

      { success?: true, order: order, error: nil }

    rescue InsufficientInventoryError => e
      { success?: false, order: nil, error: e.message }
    rescue ActiveRecord::RecordInvalid => e
      { success?: false, order: nil, error: e.message }
    end

    private

    # Lock all relevant ticket types in a single query to minimize lock duration and reduce deadlock risk.
    def lock_ticket_types!
      ids = @items.map { |i| i[:ticket_type_id] }

      # Order by ID to avoid deadlocks when two transactions try to lock the same set in different orders.
      TicketType.where(id: ids).order(:id).lock('FOR UPDATE')
    end

    # Check ticket availability after locking the rows to ensure up to date data.
    def validate_availability!(ticket_types)
      @items.each do |item|
        ticket_type = ticket_types.find { |t| t.id == item[:ticket_type_id] }
        available_amount = ticket_type.total_quantity - ticket_type.sold_quantity

        if available_amount < item[:quantity]
          raise InsufficientInventoryError, "Only #{available_amount} ticket(s) left for '#{ticket_type.name}'"
        end
      end
    end

    # Build the order and associated order items.
    def build_order(ticket_types)
      order = Order.create!(
        status:    'confirmed',
        currency:  'USD',
        placed_at: Time.current,
        email:     @email
      )

      @items.each do |item|
        ticket_type = ticket_types.find { |t| t.id == item[:ticket_type_id] }

        order.order_items.create!(
          ticket_type:               ticket_type,
          quantity:                  item[:quantity],
          unit_price_cents_snapshot: ticket_type.price_cents
        )
      end

      order.update!(total_cents: order.get_total_cents)
      order
    end

    # Increment the sold quantity for each ticket type.
    def decrement_inventory!(ticket_types)
      @items.each do |item|
        ticket_type = ticket_types.find { |t| t.id == item[:ticket_type_id] }
        ticket_type.increment!(:sold_quantity, item[:quantity])
      end
    end

    class InsufficientInventoryError < StandardError; end
  end
end
