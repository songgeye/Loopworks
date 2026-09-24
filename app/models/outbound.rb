class Outbound < ApplicationRecord
  belongs_to :counterparty
  belongs_to :staff
  has_many :outbound_materials

  def declared_total_kg
    outbound_materials.sum(:declared_kg)
  end
end
