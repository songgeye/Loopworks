class Inbound < ApplicationRecord
  belongs_to :counterparty
  belongs_to :staff
  has_many :inbound_materials

  def declared_total_kg
    inbound_materials.sum(:declared_kg)
  end
end
