class Material < ApplicationRecord
  has_many :inbound_materials
  has_many :outbound_materials
  has_many :inventory_movements
  acts_as_paranoid

  validates :name, presence: true, uniqueness: true
  validates :display_order, presence: true, numericality: { only_integer: true, greater_than: 0 }
end
