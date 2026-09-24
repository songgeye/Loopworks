class InboundsMaterial < ApplicationRecord
  belongs_to :material
  belongs_to :inbound
  has_one :inventory_movement, as: :source
end
