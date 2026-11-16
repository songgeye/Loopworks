# frozen_string_literal: true

require "test_helper"

class CounterpartiesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = create_staff(role: "admin")
    @worker = create_staff(role: "staff")
    @counterparty = create_counterparty(
      name: "山田太郎", party_type: :individual, address: "東京都千代田区1-1",
      date_of_birth: Date.new(1980, 1, 2), id_type: :drivers_license
    )
  end

  # --- 一覧 ---

  test "ログインしていないと、一覧は401になる" do
    get counterparties_path, as: :json

    assert_response :unauthorized
  end

  test "作業員も一覧を見られるが、住所などの個人情報は含まれない" do
    get counterparties_path, headers: auth_headers(@worker), as: :json

    assert_response :ok
    assert_equal [{ "id" => @counterparty.id, "name" => "山田太郎", "party_type" => "individual" }],
                 response.parsed_body
  end

  test "無効化した取引先は、一覧に出ない" do
    @counterparty.update!(deleted_at: Time.current)
    active = create_counterparty(name: "有効な取引先")

    get counterparties_path, headers: auth_headers(@worker), as: :json

    assert_equal [active.id], response.parsed_body.map { |row| row["id"] }
  end

  # --- 詳細 ---

  test "管理者は、詳細(住所・生年月日・身分証区分)を見られる" do
    get counterparty_path(@counterparty), headers: auth_headers(@admin), as: :json

    assert_response :ok
    body = response.parsed_body
    assert_equal "山田太郎", body["name"]
    assert_equal "individual", body["party_type"]
    assert_equal "東京都千代田区1-1", body["address"]
    assert_equal "1980-01-02", body["date_of_birth"]
    assert_equal "drivers_license", body["id_type"]
    assert body.key?("id_confirmed_at")
  end

  test "作業員は、詳細を見られない" do
    get counterparty_path(@counterparty), headers: auth_headers(@worker), as: :json

    assert_response :forbidden
    assert_equal ["権限がありません"], response.parsed_body["errors"]
  end

  test "存在しない・無効化済みの取引先の詳細は、404になる" do
    headers = auth_headers(@admin)

    get counterparty_path(999_999), headers: headers, as: :json
    assert_response :not_found
    assert_equal ["対象が見つかりません"], response.parsed_body["errors"]

    @counterparty.update!(deleted_at: Time.current)
    get counterparty_path(@counterparty), headers: headers, as: :json
    assert_response :not_found
  end

  # --- 登録 ---

  test "管理者は、取引先を登録できる" do
    assert_difference "Counterparty.count", 1 do
      post counterparties_path,
           params: { counterparty: { name: "新しい取引先", party_type: "corporate", address: "大阪府" } },
           headers: auth_headers(@admin),
           as: :json
    end

    assert_response :created
    created = Counterparty.last
    assert_equal({ "id" => created.id, "name" => "新しい取引先", "party_type" => "corporate" }, response.parsed_body)
    assert_equal "大阪府", created.address
  end

  test "作業員は、取引先を登録できない" do
    assert_no_difference "Counterparty.count" do
      post counterparties_path,
           params: { counterparty: { name: "新しい取引先", party_type: "corporate" } },
           headers: auth_headers(@worker),
           as: :json
    end

    assert_response :forbidden
  end

  test "名前がない・区分が正しくないと、422になる" do
    assert_no_difference "Counterparty.count" do
      post counterparties_path,
           params: { counterparty: { name: "", party_type: "unknown" } },
           headers: auth_headers(@admin),
           as: :json
    end

    assert_response :unprocessable_entity
    assert_includes response.parsed_body["errors"], "Name can't be blank"
    assert_includes response.parsed_body["errors"], "Party type is not included in the list"
  end

  # --- 更新 ---

  test "管理者は、取引先を更新できる" do
    patch counterparty_path(@counterparty),
          params: { counterparty: { name: "山田次郎", id_type: "passport" } },
          headers: auth_headers(@admin),
          as: :json

    assert_response :ok
    assert_equal "山田次郎", response.parsed_body["name"]
    assert_equal "passport", response.parsed_body["id_type"]
    assert_equal "山田次郎", @counterparty.reload.name
  end

  test "更新の内容が正しくないと、422になり変更されない" do
    patch counterparty_path(@counterparty),
          params: { counterparty: { name: "" } },
          headers: auth_headers(@admin),
          as: :json

    assert_response :unprocessable_entity
    assert_equal "山田太郎", @counterparty.reload.name
  end

  test "作業員は、取引先を更新できない" do
    patch counterparty_path(@counterparty),
          params: { counterparty: { name: "山田次郎" } },
          headers: auth_headers(@worker),
          as: :json

    assert_response :forbidden
    assert_equal "山田太郎", @counterparty.reload.name
  end

  # --- 無効化 ---

  test "管理者が削除すると、行は残したまま無効化される" do
    assert_no_difference "Counterparty.count" do
      delete counterparty_path(@counterparty), headers: auth_headers(@admin), as: :json
    end

    assert_response :ok
    assert_equal @counterparty.id, response.parsed_body["id"]
    assert_not_nil @counterparty.reload.deleted_at
  end

  test "作業員は、取引先を無効化できない" do
    delete counterparty_path(@counterparty), headers: auth_headers(@worker), as: :json

    assert_response :forbidden
    assert_nil @counterparty.reload.deleted_at
  end
end
