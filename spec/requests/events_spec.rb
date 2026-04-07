require "rails_helper"

RSpec.describe 'Events API', type: :request do
  let!(:upcoming_event) { create(:event, name: 'Jazz Night', starts_at: 1.week.from_now, ends_at: 1.week.from_now + 4.hours) }
  let!(:another_upcoming_event) { create(:event, name: 'Comedy Show', starts_at: 2.weeks.from_now, ends_at: 2.weeks.from_now + 2.hours) }
  let!(:past_event) { create(:event, name: 'Old Concert', starts_at: 1.month.ago, ends_at: 1.month.ago + 3.hours) }

  let!(:ga_ticket) { create(:ticket_type, event: upcoming_event, name: 'General Admission', price_cents: 2500, total_quantity: 100, sold_quantity: 10) }
  let!(:vip_ticket) { create(:ticket_type, event: upcoming_event, name: 'VIP', price_cents: 7500, total_quantity: 20, sold_quantity:  5) }

  # ----------------------------------------------------------------
  # GET /events
  # ----------------------------------------------------------------
  describe 'GET /events' do
    before { get '/events', as: :json }

    it 'returns 200 OK' do
      expect(response).to have_http_status(:ok)
    end

    it 'returns JSON content type' do
      expect(response.content_type).to match(%r{application/json})
    end

    it 'only returns upcoming events, not past ones' do
      names = json.map { |e| e['name'] }
      expect(names).to include('Jazz Night', 'Comedy Show')
      expect(names).not_to include('Old Concert')
    end

    it 'returns events ordered by starts_at ascending' do
      names = json.map { |e| e['name'] }
      expect(names).to eq(['Jazz Night', 'Comedy Show'])
    end

    it 'returns the correct number of upcoming events' do
      expect(json.length).to eq(2)
    end

    it 'each event includes an id' do
      json.each { |e| expect(e['id']).to be_present }
    end

    it 'each event includes a name' do
      json.each { |e| expect(e['name']).to be_present }
    end

    it 'each event includes starts_at as ISO8601' do
      json.each { |e| expect(e['starts_at']).to match(/\d{4}-\d{2}-\d{2}T/) }
    end

    it 'each event includes ends_at as ISO8601' do
      json.each { |e| expect(e['ends_at']).to match(/\d{4}-\d{2}-\d{2}T/) }
    end

    context 'when there are no upcoming events' do
      before do
        TicketType.delete_all
        Event.delete_all
        get '/events', as: :json
      end

      it 'returns an empty array' do
        expect(json).to eq([])
      end

      it 'still returns 200' do
        expect(response).to have_http_status(:ok)
      end
    end
  end

  # ----------------------------------------------------------------
  # GET /events/:id
  # ----------------------------------------------------------------
  describe 'GET /events/:id' do
    context 'when the event exists' do
      before { get "/events/#{upcoming_event.id}", as: :json }

      it 'returns 200 OK' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns the correct event id' do
        expect(json['id']).to eq(upcoming_event.id)
      end

      it 'returns the event name' do
        expect(json['name']).to eq('Jazz Night')
      end

      it 'returns starts_at as ISO8601' do
        expect(json['starts_at']).to eq(upcoming_event.starts_at.iso8601)
      end

      it 'returns ends_at as ISO8601' do
        expect(json['ends_at']).to eq(upcoming_event.ends_at.iso8601)
      end

      # --- ticket types ---
      it 'includes ticket types' do
        expect(json['ticket_types']).to be_an(Array)
        expect(json['ticket_types'].length).to eq(2)
      end

      it 'each ticket type includes an id' do
        json['ticket_types'].each { |tt| expect(tt['ticket_type_id']).to be_present }
      end

      it 'each ticket type includes a name' do
        expect(json['ticket_types'].map { |tt| tt['ticket_type_name'] })
          .to match_array(['General Admission', 'VIP'])
      end

      it 'each ticket type includes total and sold quantity' do
        ga = json['ticket_types'].find { |tt| tt['ticket_type_name'] == 'General Admission' }
        expect(ga['total_quantity']).to eq(100)
        expect(ga['sold_quantity']).to eq(10)
      end

      it 'each ticket type includes price_cents' do
        ga = json['ticket_types'].find { |tt| tt['ticket_type_name'] == 'General Admission' }
        expect(ga['price_cents']).to eq(2500)
      end

      it 'each ticket type includes a formatted price' do
        ga = json['ticket_types'].find { |tt| tt['ticket_type_name'] == 'General Admission' }
        expect(ga['unit_price']).to eq('amount' => 25.0, 'currency' => 'USD')
      end

      it 'returns an empty ticket_types array when the event has no ticket types' do
        event_no_tickets = create(:event)
        get "/events/#{event_no_tickets.id}", as: :json
        expect(json['ticket_types']).to eq([])
      end
    end

    context 'when the event does not exist' do
      before { get '/events/999999', as: :json }

      it 'returns 404 Not Found' do
        expect(response).to have_http_status(:not_found)
      end

      it 'returns an error message' do
        expect(json['error']).to match(/not found/i)
      end
    end

    context 'when the event is in the past' do
      before { get "/events/#{past_event.id}", as: :json }

      it 'still returns it by ID (show has no date filter)' do
        expect(response).to have_http_status(:ok)
        expect(json['id']).to eq(past_event.id)
      end
    end
  end
end
