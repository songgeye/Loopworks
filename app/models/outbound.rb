class Outbound < ApplicationRecord
  belongs_to :counterparty
  belongs_to :staff
  has_many :outbounds_materials

  accepts_nested_attributes_for :outbounds_materials, allow_destroy: true, reject_if: :all_blank

  def declared_total_kg
    outbounds_materials.sum(:declared_kg)
  end

  def cancelled?
    outbounds_materials.any? &&
      outbounds_materials.all? do |outbound_material|
        MaterialMovement.where(source: outbound_material)
                        .where.not(reverses_id: nil)
                        .exists?
      end
  end
end
