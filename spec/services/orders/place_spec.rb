require "rails_helper"

RSpec.describe Orders::Place do
  let(:event) { create(:event, name: 'Test Event') }
  let(:ga_type) { create(:ticket_type, event: event, name: 'General Admission', price_cents: 2500, total_quantity: 10, sold_quantity: ga_type_sold) }
  let(:vip_type) { create(:ticket_type, event: event, name: 'VIP', price_cents: 7500, total_quantity: 5, sold_quantity: 0) }

  let(:ga_type_sold) { 0 }
  let(:items) { [{ ticket_type_id: ga_type.id, quantity: 2 }, { ticket_type_id: vip_type.id, quantity: 1 }] }
  let(:result) { described_class.new(items: items).call }

  # Check happy path
  describe 'successful purchase' do
    it 'returns a successful result' do
      expect(result[:success?]).to be true
    end

    it 'creates a confirmed order' do
      expect(result[:order].status).to eq('confirmed')
      expect(result[:order].placed_at).not_to be_nil
    end

    it 'creates order items with the correct quantity' do
      expect(result[:order].order_items.first.quantity).to eq(2)
      expect(result[:order].order_items.first.ticket_type).to eq(ga_type)

      expect(result[:order].order_items.second.quantity).to eq(1)
      expect(result[:order].order_items.second.ticket_type).to eq(vip_type)
    end

    it 'increments sold_quantity on the ticket types' do
      result

      expect(ga_type.reload.sold_quantity).to eq(2)
      expect(vip_type.reload.sold_quantity).to eq(1)
    end

    it 'calculates the correct order total' do
      expect(result[:order].total_cents).to eq(12500)
    end

    it 'supports multiple ticket types in a single order' do
      expect(result[:order].order_items.count).to eq(2)
    end
  end

  # Check invalid input handling
  describe 'invalid input' do
    let(:items) { [] }
    
    it 'returns a failed result' do
      expect(result[:success?]).to be false
    end

    it 'includes a descriptive error message' do
      expect(result[:error]).to match(/no items/i)
    end

    it 'does not create an order' do
      expect { result }.not_to change(Order, :count)
    end
  end

  # Check price snapshot behavior
  describe 'price snapshot' do
    it 'freezes the price at time of purchase, not current price' do
      original_price = ga_type.price_cents  # 2500

      result

      # Promoter raises price after sale
      ga_type.update!(price_cents: 9999)

      item = result[:order].order_items.first
      expect(item.unit_price_cents_snapshot).to eq(original_price)
      expect(item.unit_price_cents_snapshot).not_to eq(ga_type.reload.price_cents)
    end
  end

  # Check insufficient inventory handling
  describe 'when inventory is insufficient' do
    # Only 1 GA ticket left, but trying to buy 2
    let(:ga_type_sold) { 9 }

    it 'returns a failed result' do
      expect(result[:success?]).to be false
    end

    it 'includes a descriptive error message' do
      expect(result[:error]).to match(/only 1 ticket/i)
    end

    it 'does not create an order' do
      expect { result }.not_to change(Order, :count)
    end

    it 'does not change sold_quantity' do
      result

      expect(ga_type.reload.sold_quantity).to eq(9)
    end

    it 'rolls back the entire order if one item in a multi-item cart fails' do
      expect { result }.not_to change(Order, :count)
      expect(vip_type.reload.sold_quantity).to eq(0)
    end
  end

  # Check concurrent purchase handling
  describe 'concurrent purchases' do
    let(:ga_type_sold) { 9 }

    it 'allows only one buyer to succeed when two race for the last ticket' do
      results = []
      threads = 2.times.map do
        Thread.new do
          # Each thread gets its own AR connection from the pool
          result = Orders::Place.new(items: [{ ticket_type_id: ga_type.id, quantity: 1 }]).call
          results << result
        end
      end
      threads.each(&:join)

      successes = results.count { |r| r[:success?] }
      failures  = results.reject { |r| r[:success?] }

      expect(successes).to eq(1)
      expect(failures.count).to eq(1)
      expect(ga_type.reload.sold_quantity).to eq(10)
    end

    it 'never exceeds total_quantity in sold_quantity' do
      5.times.map do
        Thread.new do
          Orders::Place.new(items: [{ ticket_type_id: ga_type.id, quantity: 1 }]).call
        end
      end.each(&:join)

      expect(ga_type.reload.sold_quantity).to eq(10)
    end
  end
end
