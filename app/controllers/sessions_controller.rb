# frozen_string_literal: true

class SessionsController < Devise::SessionsController
  respond_to :json

  private

  def respond_with(resource, _opts = {})
    render json: { id: resource.id, username: resource.username, role: resource.role }, status: :ok
  end

  def respond_to_on_destroy(*)
    render json: { message: "ログアウトしました" }, status: :ok
  end
end
