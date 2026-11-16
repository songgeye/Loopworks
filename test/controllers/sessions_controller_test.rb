# frozen_string_literal: true

require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @staff = create_staff(role: "admin")
  end

  test "正しいユーザー名とパスワードでログインでき、JWTが返る" do
    post staff_session_path,
         params: { staff: { username: @staff.username, password: "password123" } },
         as: :json

    assert_response :ok
    assert_equal({ "id" => @staff.id, "username" => @staff.username, "role" => "admin" }, response.parsed_body)
    assert_match(/\ABearer .+/, response.headers["Authorization"])
  end

  test "パスワードが違うとログインできない" do
    post staff_session_path,
         params: { staff: { username: @staff.username, password: "wrong-password" } },
         as: :json

    assert_response :unauthorized
    assert_nil response.headers["Authorization"]
  end

  test "無効化されたスタッフはログインできない" do
    @staff.update!(deleted_at: Time.current)

    post staff_session_path,
         params: { staff: { username: @staff.username, password: "password123" } },
         as: :json

    assert_response :unauthorized
  end

  test "ログイン後に無効化されたスタッフのJWTは使えない" do
    headers = auth_headers(@staff)
    @staff.update!(deleted_at: Time.current)

    get staffs_path, headers: headers, as: :json

    assert_response :unauthorized
  end

  test "ログアウトすると、そのJWTは使えなくなる" do
    headers = auth_headers(@staff)

    assert_difference "JwtDenylist.count", 1 do
      delete destroy_staff_session_path, headers: headers, as: :json
    end
    assert_response :ok
    assert_equal "ログアウトしました", response.parsed_body["message"]

    get staffs_path, headers: headers, as: :json
    assert_response :unauthorized
  end

  test "JWTがないと、ログインが必要なAPIは401になる" do
    get staffs_path, as: :json

    assert_response :unauthorized
  end
end
