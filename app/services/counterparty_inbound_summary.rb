# frozen_string_literal: true

class CounterpartyInboundSummary
  def self.call
    rows = MaterialMovement
             .where(source_type: "InboundsMaterial", reverses_id: nil)
             .where.not(id: MaterialMovement.where.not(reverses_id: nil).select(:reverses_id))
             .joins("INNER JOIN inbounds_materials ON inbounds_materials.id = material_movements.source_id")
             .joins("INNER JOIN inbounds ON inbounds.id = inbounds_materials.inbound_id")
             .group("inbounds.counterparty_id")
             .pluck(
               "inbounds.counterparty_id",
               Arel.sql("SUM(material_movements.quantity_kg)"),
               Arel.sql("COUNT(DISTINCT inbounds.id)")
             )

    names = Counterparty.where(id: rows.map(&:first)).pluck(:id, :name).to_h

    rows
      .map do |counterparty_id, total, count|
      { counterparty_id: counterparty_id, name: names[counterparty_id], total_kg: total.to_f, count: count }
    end
      .sort_by { |row| -row[:total_kg] }
  end
end