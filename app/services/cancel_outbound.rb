# frozen_string_literal: true

class CancelOutbound
  def self.call(outbound:, staff:)
    ActiveRecord::Base.transaction do
      recorded_at = Time.zone.now
      outbound.outbounds_materials.each do |outbounds_material|
        movement = MaterialMovement.find_by!(source: outbounds_material, reverses_id: nil)
        ReverseMaterialMovement.call(movement: movement, staff: staff, recorded_at: recorded_at)
      end
      outbound
    end
  end
end
