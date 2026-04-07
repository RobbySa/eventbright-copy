class OrdersController < ApplicationController
  def index
    if params[:email].blank?
      return render json: { error: "email param is required" }, status: :bad_request
    end

    orders = Order.where(email: params[:email].downcase.strip)
                  .includes(order_items: :ticket_type)
                  .order(created_at: :desc)

    render json: orders.map { |order| OrderSerializer.new(order).as_json }, status: :ok
  end

  def create
    # params[:items] = [{ ticket_type_id:, quantity: }]
    result = Orders::Place.new(email: params[:email], items: params[:items]).call

    if result[:success?]
      render json: OrderSerializer.new(result[:order]), status: :created
    else
      render json: { error: result[:error] }, status: :unprocessable_content
    end
  end

  def show
    order = Order.includes(order_items: :ticket_type).find(params[:id])

    render json: OrderSerializer.new(order), status: :ok
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Order not found" }, status: :not_found
  end
end
