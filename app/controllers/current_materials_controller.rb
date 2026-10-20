# frozen_string_literal: true

class CurrentMaterialsController < ApplicationController
  skip_before_action :authenticate_staff! # TODO: 認証ブランチで削除

  def index
    materials = Material.includes(:current_material).order(:display_order)
    render json: materials.map { |material| stock_json(material) }
  end

  private

  def stock_json(material)
    quantity = (material.current_material&.quantity_kg || 0).to_f
    {
      material_id: material.id,
      name: material.name,
      quantity_kg: quantity,
      stock_target: material.stock_target
    }
  end
end
