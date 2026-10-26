class MaterialMovement < ApplicationRecord
  belongs_to :material
  belongs_to :source, polymorphic: true, optional: true
  belongs_to :staff
  belongs_to :original_movement, class_name: "MaterialMovement", foreign_key: :reverses_id, optional: true
  has_one :reversal_movement, class_name: "MaterialMovement", foreign_key: :reverses_id

  def reversal?
    reverses_id.present?
  end
end
