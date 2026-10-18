# frozen_string_literal: true

class InboundsController < ApplicationController

  skip_before_action :authenticate_staff!

  def create
    inbound = CreateInbound.call(inbound_params)
    render json: { id: inbound.id }, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  private

  def inbound_params
    params.require(:inbound).permit(
      :counterparty_id, :staff_id, :counterparty_pic_name, :slip_no, :billing_no,
      inbounds_materials_attributes: [:material_id, :quantity_kg, :declared_kg]
    )
  end
end
