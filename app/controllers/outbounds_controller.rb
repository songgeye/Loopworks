# frozen_string_literal: true

class OutboundsController < ApplicationController

  before_action :require_admin

  def index
    from = parse_date(params[:from])
    to = parse_date(params[:to])

    outbounds = Outbound.includes(:counterparty, :staff, outbounds_materials: :material)
                        .order(recorded_at: :desc, id: :desc)
    outbounds = outbounds.where(recorded_at: from.in_time_zone.midnight..) if from
    outbounds = outbounds.where(recorded_at: ...(to + 1).in_time_zone) if to

    rows = outbounds.map { |outbound| outbound_json(outbound) }
    active = rows.reject { |row| row[:cancelled] }

    render json: {
      outbounds: rows,
      total_count: active.size,
      total_kg: active.sum { |row| row[:total_kg] }.round(2)
    }
  rescue Date::Error
    render json: { errors: ["日付の形式が正しくありません(例: 2026-11-06)"] }, status: :unprocessable_entity
  end

  def create
    outbound = CreateOutbound.call(outbound_params)
    material_ids = outbound.outbounds_materials.map(&:material_id)
    warnings = CheckStockShortage.call(material_ids)
    render json: { id: outbound.id, warnings: warnings }, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  def destroy
    outbound = Outbound.find(params[:id])
    staff = Staff.find(params.require(:staff_id))
    CancelOutbound.call(outbound: outbound, staff: staff)
    render json: { id: outbound.id }
  rescue ActiveRecord::RecordNotFound
    render json: { errors: ["対象が見つかりません"] }, status: :not_found
  rescue ArgumentError => e
    render json: { errors: [e.message] }, status: :unprocessable_entity
  end

  private

  def outbound_params
    params.require(:outbound).permit(
      :counterparty_id, :staff_id, :counterparty_pic_name, :slip_no, :billing_no,
      outbounds_materials_attributes: [:material_id, :quantity_kg, :declared_kg]
    )
  end

  def parse_date(value)
    Date.iso8601(value) if value.present?
  end

  def outbound_json(outbound)
    items = outbound.outbounds_materials.map do |outbounds_material|
      { id: outbounds_material.id,
        material_id: outbounds_material.material_id,
        material_name: outbounds_material.material.name,
        quantity_kg: outbounds_material.quantity_kg.abs.to_f,
        declared_kg: outbounds_material.declared_kg&.to_f
      }
    end
    {
      id: outbound.id,
      recorded_at: outbound.recorded_at,
      slip_no: outbound.slip_no,
      counterparty_pic_name: outbound.counterparty_pic_name,
      counterparty: { id: outbound.counterparty_id, name: outbound.counterparty.name },
      staff: { id: outbound.staff_id, name: outbound.staff.name },
      items: items,
      total_kg: items.sum { |item| item[:quantity_kg] },
      cancelled: outbound.cancelled?
    }
  end
end
