class MaterialsController < ApplicationController
  MATERIAL_JSON_FIELDS = [:id, :name, :display_order, :stock_target].freeze
  skip_before_action :authenticate_staff!, only: [:index, :show]
  before_action :set_material, only: [:show, :update, :destroy]
  before_action :require_admin, only: [:create, :update, :destroy]

  def index
    materials = Material.order(:display_order)
    render json: materials.map { |material| material_json(material) }
  end

  def create
    material = Material.new(material_params)
    if material.save
      render json: material_json(material), status: :created
    else
      render json: { errors: material.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def show
    render json: material_json(@material)
  end

  def update
    if @material.update(material_params)
      render json: material_json(@material)
    else
      render json: { errors: @material.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @material.destroy
    render json: { message: "品目を削除しました" }, status: :ok
  end

  private

  def material_json(material)
    material.as_json(only: MATERIAL_JSON_FIELDS)
  end

  def set_material
    @material = Material.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { errors: ["品目が見つかりません"] }, status: :not_found
  end

  def require_admin
    return if current_staff&.admin?
    render json: { errors: ["権限がありません"] }, status: :forbidden
  end

  def material_params
    params.require(:material).permit(:name, :display_order)
  end
end
