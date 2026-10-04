class AdjustmentMaterial < ApplicationRecord
  belongs_to :material
  belongs_to :staff
  has_one :material_movement, as: :source

  validates :note, presence: true

  attr_accessor :direction

  before_validation :apply_direction

  validates :note, presence: true
  validates :quantity_kg, numericality: { other_than: 0 }

  before_update :prevent_update

  private

  def apply_direction
    return if direction.blank? || quantity_kg.nil?
    self.quantity_kg = direction == "decrease" ? -quantity_kg.abs : quantity_kg.abs
  end

  def prevent_update
    raise ActiveRecord::ReadOnlyRecord if persisted? && changed?
  end
end
