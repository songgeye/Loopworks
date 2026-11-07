class Inbound < ApplicationRecord
  belongs_to :counterparty
  belongs_to :staff
  has_many :inbounds_materials

  accepts_nested_attributes_for :inbounds_materials, allow_destroy: true, reject_if: :all_blank

  def declared_total_kg
    inbounds_materials.sum(:declared_kg)
  end

  def cancelled?
    inbounds_materials.any? &&
      inbounds_materials.all? do |inbounds_material|
        MaterialMovement.where(source: inbounds_material)
                        .where.not(reverses_id: nil)
                        .exists?
      end
  end

  def editable_by?(user)
    inbounds_materials.all? do |inbounds_material|
      inbounds_material.editable_by?(user)
    end
  end
end
