require "rails_helper"

RSpec.describe "Orders API", type: :request do
  let(:event) { create(:event) }
  let(:ga_type) { create(:ticket_type, event: event, name: 'General Admission', price_cents: 2500, total_quantity: 10, sold_quantity: ga_sold_quantity) }
  let(:vip_type) { create(:ticket_type, event: event, name: 'VIP', price_cents: 7500, total_quantity: 5, sold_quantity: 0) }

  let(:ga_sold_quantity) { 0 }
  let(:valid_params) { { items: [{ ticket_type_id: ga_type.id, quantity: 2 }] } }

  # ----------------------------------------------------------------
  # POST /orders
  # ----------------------------------------------------------------
  describe 'POST /orders' do
    context 'with valid params' do
      before { post '/orders', params: valid_params, as: :json }

      it 'returns 201 Created' do
        expect(response).to have_http_status(:created)
      end

      it 'returns JSON content type' do
        expect(response.content_type).to match(%r{application/json})
      end

      # Check order fields
      it 'includes the order id' do
        expect(json['id']).to be_present
      end

      it 'returns status as confirmed' do
        expect(json['status']).to eq('confirmed')
      end

      it 'returns correct total_cents' do
        expect(json['total_cents']).to eq(5000)  # 2 × 2500
      end

      it 'returns a formatted total with amount and currency' do
        expect(json['total']).to eq("amount" => 50.0, "currency" => "USD")
      end

      it 'includes placed_at timestamp' do
        expect(json['placed_at']).to be_present
      end

      # Check order items fields
      it 'includes one order item' do
        expect(json['items'].length).to eq(1)
      end

      it 'includes the correct ticket type name' do
        expect(json['items'][0]['ticket_type_name']).to eq('General Admission')
      end

      it 'includes the correct quantity' do
        expect(json['items'][0]['quantity']).to eq(2)
      end

      it 'includes the price snapshot, not live price' do
        expect(json['items'][0]['unit_price_cents']).to eq(2500)
      end
    end

    # Check that multiple items are handled correctly.
    context 'with multiple ticket types' do
      let(:valid_params) { { items: [{ ticket_type_id: ga_type.id, quantity: 2 }, { ticket_type_id: vip_type.id, quantity: 1 }] } }

      before { post '/orders', params: valid_params, as: :json }

      it 'returns two order items' do
        expect(json['items'].length).to eq(2)
      end

      it 'returns the correct combined total' do
        expect(json['total_cents']).to eq(12500)  # 5000 + 7500
      end
    end

    # Check insufficient inventory handling
    context 'when ticket is sold out' do
      let(:ga_sold_quantity) { 10 }

      before do
        # Clear any existing orders to avoid interference 
        # normally not needed but I have intruduced as the test was failing otherwise.
        Order.destroy_all
        post '/orders', params: valid_params, as: :json
      end

      it 'returns 422 Unprocessable Entity' do
        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'returns an error message' do
        expect(json['error']).to match(/only 0 ticket/i)
      end

      it 'does not create an order' do
        expect(Order.count).to eq(0)
      end
    end

    context 'when requesting more tickets than available' do
      let(:valid_params) { { items: [{ ticket_type_id: ga_type.id, quantity: 999 }] } }

      before { post '/orders', params: valid_params, as: :json }

      it 'returns 422' do
        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'returns a descriptive error' do
        expect(json['error']).to be_present
      end
    end

    context 'with missing items' do
      let(:valid_params) { { items: [] } }

      before do
        post '/orders', params: valid_params, as: :json
      end

      it 'returns 422' do
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end
end
