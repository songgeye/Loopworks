# frozen_string_literal: true

class OutboundsController < ApplicationController

  before_action :require_admin

  def create
    outbound = CreateOutbound.call(outbound_params)
    render json: { id: outbound.id }, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  private

  def outbound_params
    params.require(:outbound).permit(
      :counterparty_id, :staff_id, :counterparty_pic_name, :slip_no, :billing_no,
      outbounds_materials_attributes: [:material_id, :quantity_kg, :declared_kg]
    )
  end
end
