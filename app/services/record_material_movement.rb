# frozen_string_literal: true

class RecordMaterialMovement

  def self.call(source:, staff:, recorded_at:)
    ActiveRecord::Base.transaction do
      raise ArgumentError, "すでに台帳に記録済みです" if MaterialMovement.exists?(source: source)


      MaterialMovement.create!(
        material: source.material,
        quantity_kg: source.quantity_kg,
        recorded_at: recorded_at,
        source: source,
        staff: staff
      )

      current = CurrentMaterial.find_or_create_by!(material: source.material)
      current.update!(quantity_kg: current.quantity_kg + source.quantity_kg)
    end
  end
end
