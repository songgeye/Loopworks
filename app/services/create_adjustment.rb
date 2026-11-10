# frozen_string_literal: true

class CreateAdjustment
    DIRECTIONS = %w[increase decrease].freeze
  
    def self.call(attributes)
      unless DIRECTIONS.include?(attributes[:direction])
        raise ArgumentError, "区分が正しくありません"
      end
  
      ActiveRecord::Base.transaction do
        adjustment = AdjustmentMaterial.create!(attributes.merge(recorded_at: Time.zone.now))
        RecordMaterialMovement.call(
          source: adjustment,
          staff: adjustment.staff,
          recorded_at: adjustment.recorded_at
        )
        adjustment
      end
    end
  end