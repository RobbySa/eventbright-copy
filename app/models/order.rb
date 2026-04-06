class Order < ApplicationRecord
  has_many :order_items, dependent: :destroy
  has_many :ticket_types, through: :order_items

  STATUSES = %w[pending confirmed, cancelled].freeze

  validates :status, inclusion: { in: STATUSES }
  validates :currency, presence: true
  validates :total_cents, numericality: { greater_than_or_equal_to: 0 }

  scope :confirmed, -> { where(status: "confirmed") }
  scope :pending,   -> { where(status: "pending") }

  def confirm!
    update!(status: "confirmed", placed_at: Time.current)
  end

  def cancel!
    update!(status: "cancelled")
  end

  def get_total_cents
    order_items.sum("quantity * unit_price_cents_snapshot")
  end
end
