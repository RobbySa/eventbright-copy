class OrderItem < ApplicationRecord
  belongs_to :order
  belongs_to :ticket_type

  validates :quantity, numericality: { greater_than: 0, only_integer: true }
  validates :unit_price_cents_snapshot, numericality: { greater_than_or_equal_to: 0 }

  before_validation :snapshot_price, on: :create

  private

  def snapshot_price
    self.unit_price_cents_snapshot ||= ticket_type&.price_cents
  end
end
