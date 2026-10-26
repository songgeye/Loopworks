# frozen_string_literal: true

class CancelInbound
  def self.call(inbound:, staff:)
    ActiveRecord::Base.transaction do
      recorded_at = Time.zone.now
      inbound.inbounds_materials.each do |inbounds_material|
        movement = MaterialMovement.find_by!(source: inbounds_material, reverses_id: nil)
        ReverseMaterialMovement.call(movement: movement, staff: staff, recorded_at: recorded_at)
      end
      inbound
    end
  end
end
