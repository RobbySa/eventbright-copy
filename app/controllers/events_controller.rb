class EventsController < ApplicationController
  def index
    events = Event.where(starts_at: DateTime.current..).order(starts_at: :asc)

    render json: events.map { |event| EventSerializer.new(event).as_json }, status: :ok
  end

  def show
    event = Event.includes(:ticket_types).find(params[:id])

    render json: EventSerializer.new(event), status: :ok
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Event not found" }, status: :not_found
  end
end