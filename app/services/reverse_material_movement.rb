# frozen_string_literal: true

class ReverseMaterialMovement
  def self.call(movement:, staff:, recorded_at:)
    ActiveRecord::Base.transaction do
      raise ArgumentError, "打ち消しの行は取り消せません" if movement.reversal?
      raise ArgumentError, "すでに取り消し済みです" if movement.reversal_movement.present?

      MaterialMovement.create!(
        material: movement.material,
        quantity_kg: -movement.quantity_kg,
        recorded_at: recorded_at,
        source: movement.source,
        staff: staff,
        original_movement: movement
      )

      current = CurrentMaterial.find_or_create_by!(material: movement.material)
      current.update!(quantity_kg: current.quantity_kg - movement.quantity_kg)
    end
  end
end
