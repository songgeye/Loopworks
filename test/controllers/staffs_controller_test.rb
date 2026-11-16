# frozen_string_literal: true

require "test_helper"

class StaffsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = create_staff(role: "admin")
    @worker = create_staff(role: "staff")
  end

  # --- 一覧 ---

  test "ログインしていないと、一覧は401になる" do
    get staffs_path, as: :json

    assert_response :unauthorized
  end

  test "管理者には、ユーザー名と役割つきで返る" do
    get staffs_path, headers: auth_headers(@admin), as: :json

    assert_response :ok
    assert_equal [
      { "id" => @admin.id, "name" => @admin.name, "username" => @admin.username, "role" => "admin" },
      { "id" => @worker.id, "name" => @worker.name, "username" => @worker.username, "role" => "staff" }
    ], response.parsed_body
  end

  test "作業員には、IDと名前だけが返る" do
    get staffs_path, headers: auth_headers(@worker), as: :json

    assert_response :ok
    assert_equal [
      { "id" => @admin.id, "name" => @admin.name },
      { "id" => @worker.id, "name" => @worker.name }
    ], response.parsed_body
  end

  test "無効化したスタッフは、一覧に出ない" do
    @worker.update!(deleted_at: Time.current)

    get staffs_path, headers: auth_headers(@admin), as: :json

    assert_equal [@admin.id], response.parsed_body.map { |row| row["id"] }
  end

  # --- 登録 ---

  test "管理者は、スタッフを登録できる" do
    assert_difference "Staff.count", 1 do
      post staffs_path,
           params: { staff: { username: "new_staff", name: "新人", role: "staff", password: "password123" } },
           headers: auth_headers(@admin),
           as: :json
    end

    assert_response :created
    created = Staff.find_by!(username: "new_staff")
    assert_equal({ "id" => created.id, "name" => "新人", "username" => "new_staff", "role" => "staff" },
                 response.parsed_body)
    assert created.valid_password?("password123")
  end

  test "登録の応答に、パスワードは含まれない" do
    post staffs_path,
         params: { staff: { username: "new_staff", name: "新人", role: "staff", password: "password123" } },
         headers: auth_headers(@admin),
         as: :json

    assert_not response.parsed_body.key?("password")
    assert_not response.parsed_body.key?("encrypted_password")
  end

  test "作業員は、スタッフを登録できない" do
    assert_no_difference "Staff.count" do
      post staffs_path,
           params: { staff: { username: "new_staff", name: "新人", role: "admin", password: "password123" } },
           headers: auth_headers(@worker),
           as: :json
    end

    assert_response :forbidden
    assert_equal ["権限がありません"], response.parsed_body["errors"]
  end

  test "ユーザー名が重複していると、422になる" do
    assert_no_difference "Staff.count" do
      post staffs_path,
           params: { staff: { username: @worker.username, name: "新人", role: "staff", password: "password123" } },
           headers: auth_headers(@admin),
           as: :json
    end

    assert_response :unprocessable_entity
    assert_includes response.parsed_body["errors"], "Username has already been taken"
  end

  test "役割が正しくないと、422になる" do
    post staffs_path,
         params: { staff: { username: "new_staff", name: "新人", role: "owner", password: "password123" } },
         headers: auth_headers(@admin),
         as: :json

    assert_response :unprocessable_entity
    assert_includes response.parsed_body["errors"], "Role is not included in the list"
  end

  # --- 更新 ---

  test "管理者は、スタッフの名前と役割を更新できる" do
    patch staff_path(@worker),
          params: { staff: { name: "改名", role: "admin" } },
          headers: auth_headers(@admin),
          as: :json

    assert_response :ok
    assert_equal "改名", response.parsed_body["name"]
    assert_equal "admin", response.parsed_body["role"]
    assert @worker.reload.admin?
  end

  test "管理者は、スタッフのパスワードを変更できる" do
    patch staff_path(@worker),
          params: { staff: { password: "new-password" } },
          headers: auth_headers(@admin),
          as: :json

    assert_response :ok
    assert @worker.reload.valid_password?("new-password")
  end

  test "作業員は、スタッフを更新できない" do
    patch staff_path(@worker),
          params: { staff: { role: "admin" } },
          headers: auth_headers(@worker),
          as: :json

    assert_response :forbidden
    assert_not @worker.reload.admin?
  end

  test "最後の管理者は、役割を作業員に変更できない" do
    patch staff_path(@admin),
          params: { staff: { role: "staff" } },
          headers: auth_headers(@admin),
          as: :json

    assert_response :unprocessable_entity
    assert_equal ["最後の管理者の役割は変更できません"], response.parsed_body["errors"]
    assert @admin.reload.admin?
  end

  test "ほかに管理者がいれば、管理者の役割を作業員に変更できる" do
    other_admin = create_staff(role: "admin")

    patch staff_path(other_admin),
          params: { staff: { role: "staff" } },
          headers: auth_headers(@admin),
          as: :json

    assert_response :ok
    assert_not other_admin.reload.admin?
  end

  test "無効化済みの管理者は、ほかの管理者として数えない" do
    create_staff(role: "admin", deleted_at: Time.current)

    patch staff_path(@admin),
          params: { staff: { role: "staff" } },
          headers: auth_headers(@admin),
          as: :json

    assert_response :unprocessable_entity
    assert @admin.reload.admin?
  end

  test "更新の内容が正しくないと、422になり変更されない" do
    patch staff_path(@worker),
          params: { staff: { username: @admin.username } },
          headers: auth_headers(@admin),
          as: :json

    assert_response :unprocessable_entity
    assert_not_equal @admin.username, @worker.reload.username
  end

  test "存在しないスタッフの更新は、404になる" do
    patch staff_path(999_999), params: { staff: { name: "改名" } }, headers: auth_headers(@admin), as: :json

    assert_response :not_found
    assert_equal ["対象が見つかりません"], response.parsed_body["errors"]
  end

  # --- 無効化 ---

  test "管理者が削除すると、行は残したまま無効化され、ログインできなくなる" do
    assert_no_difference "Staff.count" do
      delete staff_path(@worker), headers: auth_headers(@admin), as: :json
    end

    assert_response :ok
    assert_equal @worker.id, response.parsed_body["id"]
    assert_not_nil @worker.reload.deleted_at

    post staff_session_path,
         params: { staff: { username: @worker.username, password: "password123" } },
         as: :json
    assert_response :unauthorized
  end

  test "自分自身は、無効化できない" do
    create_staff(role: "admin")

    delete staff_path(@admin), headers: auth_headers(@admin), as: :json

    assert_response :unprocessable_entity
    assert_equal ["自分自身は無効化できません"], response.parsed_body["errors"]
    assert_nil @admin.reload.deleted_at
  end

  test "ほかの管理者は、無効化できる" do
    other_admin = create_staff(role: "admin")

    delete staff_path(other_admin), headers: auth_headers(@admin), as: :json

    assert_response :ok
    assert_not_nil other_admin.reload.deleted_at
  end

  test "作業員は、スタッフを無効化できない" do
    delete staff_path(@admin), headers: auth_headers(@worker), as: :json

    assert_response :forbidden
    assert_nil @admin.reload.deleted_at
  end

  test "無効化済みのスタッフをもう一度無効化すると、404になる" do
    @worker.update!(deleted_at: Time.current)

    delete staff_path(@worker), headers: auth_headers(@admin), as: :json

    assert_response :not_found
  end
end
