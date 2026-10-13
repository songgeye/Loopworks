# frozen_string_literal: true

class CreateOutbound
  def self.call(attributes)
    ActiveRecord::Base.transaction do
      outbound = Outbound.create!(attributes.merge(recorded_at: Time.zone.now))
      outbound.outbounds_materials.each do |outbounds_material|
        RecordMaterialMovement.call(
          source: outbounds_material,
          staff: outbound.staff,
          recorded_at: outbound.recorded_at
        )
      end
      outbound
    end
  end
end
