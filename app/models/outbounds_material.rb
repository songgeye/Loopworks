class OutboundsMaterial < ApplicationRecord
  belongs_to :outbound
  belongs_to :material
  has_one :inventory_movement, as: :source
end
