class OrdersController < ApplicationController
  def create
    # params[:items] = [{ ticket_type_id:, quantity: }]
    result = Orders::Place.new(items: params[:items]).call

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
