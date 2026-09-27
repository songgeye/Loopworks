class InboundsMaterial < ApplicationRecord
  belongs_to :material
  belongs_to :inbound
  has_one :material_movement, as: :source

  def business_date
    BusinessDay.from(inbound.recorded_at)
  end

  def editable_by?(user)
    return true if user.admin?
    business_date == BusinessDay.current
  end
end
