# frozen_string_literal: true

class StaffsController < ApplicationController
  before_action :require_admin, only: [ :create, :update, :destroy ]
  before_action :set_staff, only: [ :update, :destroy ]

  def index
    staffs = Staff.where(deleted_at: nil).order(:id)
    render json: staffs.map { |staff| staff_json(staff) }
  end

  def create
    staff = Staff.new(staff_params)

    if staff.save
      render json: staff.slice(:id, :name, :username, :role), status: :created
    else
      render json: { errors: staff.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    @staff.assign_attributes(staff_params)

    if @staff.role_was == "admin" && !@staff.admin? && !other_active_admin_exists?(@staff)
      return render json: { errors: [ "最後の管理者の役割は変更できません" ] }, status: :unprocessable_entity
    end

    if @staff.save
      render json: @staff.slice(:id, :name, :username, :role)
    else
      render json: { errors: @staff.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    if @staff == current_staff
      return render json: { errors: [ "自分自身は無効化できません" ] }, status: :unprocessable_entity
    end
    if @staff.admin? && !other_active_admin_exists?(@staff)
      return render json: { errors: [ "最後の管理者は無効化できません" ] }, status: :unprocessable_entity
    end

    @staff.update!(deleted_at: Time.current)
    render json: { id: @staff.id }
  end

  private

  def set_staff
    @staff = Staff.where(deleted_at: nil).find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { errors: [ "対象が見つかりません" ] }, status: :not_found
  end

  def staff_json(staff)
    json = staff.slice(:id, :name)
    json.merge!(staff.slice(:username, :role)) if current_staff&.admin?
    json
  end

  def other_active_admin_exists?(staff)
    Staff.where(role: "admin", deleted_at: nil).where.not(id: staff.id).exists?
  end

  def staff_params
    params.require(:staff).permit(:username, :name, :role, :password)
  end
end
