# frozen_string_literal: true

class InboundsController < ApplicationController

  def index
    from = parse_date(params[:from])
    to = parse_date(params[:to])

    inbounds = Inbound.includes(:counterparty, :staff, inbounds_materials: :material)
                      .order(recorded_at: :desc, id: :desc)
    inbounds = inbounds.where(recorded_at: from.in_time_zone..) if from
    inbounds = inbounds.where(recorded_at: ...(to + 1).in_time_zone) if to

    rows = inbounds.map { |inbound| inbound_json(inbound) }
    active = rows.reject { |row| row[:cancelled] }

    render json: {
      inbounds: rows,
      total_count: active.size,
      total_kg: active.sum { |row| row[:total_kg] }.round(2)
    }
  rescue Date::Error
    render json: { errors: ["日付の形式が正しくありません(例: 2026-11-06)"] }, status: :unprocessable_entity
  end

  def create
    inbound = CreateInbound.call(inbound_params)
    render json: { id: inbound.id }, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  def destroy
    inbound = Inbound.find(params[:id])
    unless inbound.editable_by?(current_staff)
      return render(json: { errors: ["権限がありません"] }, status: :forbidden)
    end

    staff = Staff.find(params.require(:staff_id))
    CancelInbound.call(inbound: inbound, staff: staff)
    warnings = CheckStockShortage.call(inbound.inbounds_materials.map(&:material_id))
    render json: { id: inbound.id, warnings: warnings }
  rescue ActiveRecord::RecordNotFound
    render json: { errors: ["対象が見つかりません"] }, status: :not_found
  rescue ArgumentError => e
    render json: { errors: [e.message] }, status: :unprocessable_entity
  end

  private

  def inbound_params
    params.require(:inbound).permit(
      :counterparty_id, :staff_id, :counterparty_pic_name, :slip_no, :billing_no,
      inbounds_materials_attributes: [:material_id, :quantity_kg, :declared_kg]
    )
  end

  def parse_date(value)
    Date.iso8601(value) if value.present?
  end

  def inbound_json(inbound)
    item = inbound.inbounds_materials.map do |inbound|
      { id: inbound.id, material_id: inbound.material_id, material_name: inbound.material.name,
       quantity: inbound.quantity.to_f, declared_kg: inbound.declared_kg&.to_f }
    end
    {
      id: inbound.id,
      recorded_at: inbound.recorded_at,
      slip_no: inbound.slip_no,
      counterparty_pic_name: inbound.counterparty_id,
      counterperty: { id: inbound.counterparty_id, name: inbound.counterparty.name },
      staff: { id: inbound.staff_id, name: inbound.staff.name },
      items: items,
      total_kg: items.sum { |item| item[:quantity_kg] },
      cancelled: inbound.cancelled?,
      editable: inbound.editable_by?(current_staff)
    }
  end
end
