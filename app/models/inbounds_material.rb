class InboundsMaterial < ApplicationRecord
  belongs_to :material
  belongs_to :inbound
  has_one :material_movement, as: :source
end
