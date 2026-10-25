# frozen_string_literal: true

class StaffsController < ApplicationController
  def index
    staffs = Staff.where(deleted_at: nil).order(:id)
    render json: staffs.map { |staff| staff.slice(:id, :name) }
  end
end
