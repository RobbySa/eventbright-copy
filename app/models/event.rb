class Event < ApplicationRecord
  validates :name, :starts_at, :ends_at, presence: true

  has_many :ticket_types, dependent: :destroy
end