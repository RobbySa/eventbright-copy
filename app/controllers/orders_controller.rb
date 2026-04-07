class OrdersController < ApplicationController
  def create
    # [{ ticket_type_id:, quantity: }]
    result = PlaceOrder.new(items: params[:items]).call

    if result[:success?]
      render json: OrderSerializer.new(result[:order]), status: :created
    else
      render json: { error: result[:error] }, status: :unprocessable_content
    end
  end
end
