class Inbound < ApplicationRecord
  belongs_to :counterparty
  belongs_to :staff
  has_many :inbounds_materials

  def declared_total_kg
    inbounds_materials.sum(:declared_kg)
  end
end
