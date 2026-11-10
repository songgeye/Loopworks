# frozen_string_literal: true

class AdjustmentMaterialsController < ApplicationControllergit branch --show-current
    before_action :require_admin
  
    def create
      adjustment = CreateAdjustment.call(adjustment_params)
      warnings = CheckStockShortage.call([adjustment.material_id])
      render json: { id: adjustment.id, warnings: warnings }, status: :created
    rescue ActiveRecord::RecordInvalid => e
      render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
    rescue ArgumentError => e
      render json: { errors: [e.message] }, status: :unprocessable_entity
    end
  
    private
  
    def adjustment_params
      params.require(:adjustment_material).permit(
        :material_id, :staff_id, :direction, :quantity_kg, :note
      )
    end
  end