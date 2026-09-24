class InventoryMovement < ApplicationRecord
  belongs_to :material
  belongs_to :source, polymorphic: true, optional: true
  belongs_to :staff
end
