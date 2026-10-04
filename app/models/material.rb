class Material < ApplicationRecord
  has_many :inbounds_materials
  has_many :outbounds_materials
  has_many :adjustment_materials
  has_many :material_movements
  has_one :current_material
  acts_as_paranoid

  validates :name, presence: true, uniqueness: true
  validates :display_order, presence: true, numericality: { only_integer: true, greater_than: 0 }
end
