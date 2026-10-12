# frozen_string_literal: true

class CreateInbound
  def self.call(attributes)
    ActiveRecord::Base.transaction do
      inbound = Inbound.create!(attributes)
      inbound.inbounds_materials.each do |inbounds_material|
        RecordMaterialMovement.call(
          source: inbounds_material,
          staff: inbound.staff,
          recorded_at: inbound.recorded_at
        )
      end
      inbound
    end
  end
end
