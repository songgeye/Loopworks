# frozen_string_literal: true

class CheckStockShortage
  def self.call(material_ids)
    Material.where(id: material_ids, stock_target: true)
            .includes(:current_material)
            .filter_map do |material|
      quantity = material.current_material&.quantity_kg || 0
      next unless quantity.negative?

      { material_id: material.id, name: material.name, shortage_kg: (-quantity).to_f }
    end
  end
end
