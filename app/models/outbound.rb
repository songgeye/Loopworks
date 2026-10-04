class Outbound < ApplicationRecord
  belongs_to :counterparty
  belongs_to :staff
  has_many :outbounds_materials

  def declared_total_kg
    outbounds_materials.sum(:declared_kg)
  end
end
