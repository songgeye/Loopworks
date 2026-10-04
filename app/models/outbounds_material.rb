class OutboundsMaterial < ApplicationRecord
  belongs_to :outbound
  belongs_to :material
  has_one :material_movement, as: :source
  before_validation :force_negative

  def business_date
    BusinessDay.from(outbound.recorded_at)
  end

  def editable_by?(user)
    return true if user&.admin?
    business_date == BusinessDay.current
  end

  def force_negative
    self.quantity_kg = -quantity_kg.abs if quantity_kg
  end
end
