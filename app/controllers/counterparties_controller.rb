# frozen_string_literal: true

class CounterpartiesController < ApplicationController

  before_action :require_admin, only: [:create, :show, :update, :destroy]
  before_action :set_counterparty, only: [:show, :update, :destroy]

  def index
    counterparties = Counterparty.where(deleted_at: nil).order(:id)
    render json: counterparties.map { |counterparty| counterparty_json(counterparty) }
  end

  def show
    render json: counterparty_detail_json(@counterparty)
  end

  def create
    counterparty = Counterparty.new(counterparty_params)

    if counterparty.save
      render json: counterparty_json(counterparty), status: :created
    else
      render json: { errors: counterparty.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @counterparty.update(counterparty_params)
      render json: counterparty_detail_json(@counterparty)
    else
      render json: { errors: @counterparty.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @counterparty.update!(deleted_at: Time.current)
    render json: { id: @counterparty.id }
  end

  private

  def set_counterparty
    @counterparty = Counterparty.where(deleted_at: nil).find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { errors: ["対象が見つかりません"] }, status: :not_found
  end

  def counterparty_json(counterparty)
    counterparty.slice(:id, :name, :party_type)
  end

  def counterparty_detail_json(counterparty)
    counterparty.slice(:id, :name, :party_type, :address, :date_of_birth, :id_type, :id_confirmed_at)
  end

  def counterparty_params
    params.require(:counterparty).permit(:name, :party_type, :address, :date_of_birth, :id_type)
  end
end
