# frozen_string_literal: true

class CounterpartiesController < ApplicationController

  before_action :require_admin, only: [:create]

  def index
    render json: Counterparty.order(:id).map { |counterparty| counterparty_json(counterparty) }
  end

  def create
    counterparty = Counterparty.new(counterparty_params)

    if counterparty.save
      render json: counterparty_json(counterparty), status: :created
    else
      render json: { errors: counterparty.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def counterparty_json(counterparty)
    counterparty.slice(:id, :name, :party_type)
  end

  def counterparty_params
    params.require(:counterparty).permit(:name, :party_type, :address, :date_of_birth, :id_type)
  end
end
