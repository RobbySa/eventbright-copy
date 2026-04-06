class Event < ApplicationRecord
  validates :title, :starts_at, :ends_at, presence: true
end