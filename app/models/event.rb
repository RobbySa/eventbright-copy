class Event < ApplicationRecord
  validates :name, :starts_at, :ends_at, presence: true
end