class Inbound < ApplicationRecord
  belongs_to :counterparty
  belongs_to :staff
  has_many :inbounds_materials

  accepts_nested_attributes_for :inbounds_materials, allow_destroy: true, reject_if: :all_blank

  def declared_total_kg
    inbounds_materials.sum(:declared_kg)
  end
end
