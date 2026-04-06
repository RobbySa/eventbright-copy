class TicketType < ApplicationRecord
  belongs_to :event

  validates :name, presence: true
  validates :price_cents, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :total_quantity, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :sold_quantity, numericality: { greater_than_or_equal_to: 0 }
  validate  :sold_quantity_cannot_exceed_total_quantity

  private

  def sold_quantity_cannot_exceed_total_quantity
    if sold_quantity > total_quantity
      errors.add(:sold_quantity, 'cannot exceed total quantity')
    end
  end
end