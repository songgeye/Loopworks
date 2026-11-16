# frozen_string_literal: true

require "test_helper"

class MaterialsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = create_staff(role: "admin")
    @worker = create_staff(role: "staff")
    @copper = create_material(name: "テスト銅", display_order: 2)
    @iron = create_material(name: "テスト鉄", display_order: 1)
  end

  # --- 一覧・詳細 ---

  test "一覧は、ログインなしで表示順に返る" do
    get materials_path, as: :json

    assert_response :ok
    assert_equal [
      { "id" => @iron.id, "name" => "テスト鉄", "display_order" => 1, "stock_target" => true },
      { "id" => @copper.id, "name" => "テスト銅", "display_order" => 2, "stock_target" => true }
    ], response.parsed_body
  end

  test "削除した品目は、一覧に出ない" do
    @copper.destroy

    get materials_path, as: :json

    assert_equal [@iron.id], response.parsed_body.map { |row| row["id"] }
  end

  test "詳細は、ログインなしで見られる" do
    get material_path(@iron), as: :json

    assert_response :ok
    assert_equal({ "id" => @iron.id, "name" => "テスト鉄", "display_order" => 1, "stock_target" => true },
                 response.parsed_body)
  end

  test "存在しない品目の詳細は、404になる" do
    get material_path(999_999), as: :json

    assert_response :not_found
    assert_equal ["品目が見つかりません"], response.parsed_body["errors"]
  end

  # --- 登録 ---

  test "管理者は、品目を登録できる" do
    assert_difference "Material.count", 1 do
      post materials_path,
           params: { material: { name: "テストアルミ", display_order: 3, stock_target: false } },
           headers: auth_headers(@admin),
           as: :json
    end

    assert_response :created
    created = Material.find_by!(name: "テストアルミ")
    assert_equal({ "id" => created.id, "name" => "テストアルミ", "display_order" => 3, "stock_target" => false },
                 response.parsed_body)
  end

  test "ログインしていないと、登録は401になる" do
    assert_no_difference "Material.count" do
      post materials_path, params: { material: { name: "テストアルミ", display_order: 3 } }, as: :json
    end

    assert_response :unauthorized
  end

  test "作業員は、品目を登録できない" do
    assert_no_difference "Material.count" do
      post materials_path,
           params: { material: { name: "テストアルミ", display_order: 3 } },
           headers: auth_headers(@worker),
           as: :json
    end

    assert_response :forbidden
    assert_equal ["権限がありません"], response.parsed_body["errors"]
  end

  test "名前が重複していると、422になる" do
    assert_no_difference "Material.count" do
      post materials_path,
           params: { material: { name: "テスト鉄", display_order: 3 } },
           headers: auth_headers(@admin),
           as: :json
    end

    assert_response :unprocessable_entity
    assert_includes response.parsed_body["errors"], "Name has already been taken"
  end

  # --- 更新 ---

  test "管理者は、品目を更新できる" do
    patch material_path(@iron),
          params: { material: { name: "テスト鉄くず", display_order: 5, stock_target: false } },
          headers: auth_headers(@admin),
          as: :json

    assert_response :ok
    assert_equal({ "id" => @iron.id, "name" => "テスト鉄くず", "display_order" => 5, "stock_target" => false },
                 response.parsed_body)
    assert_equal "テスト鉄くず", @iron.reload.name
  end

  test "更新の内容が正しくないと、422になり変更されない" do
    patch material_path(@iron),
          params: { material: { display_order: 0 } },
          headers: auth_headers(@admin),
          as: :json

    assert_response :unprocessable_entity
    assert_equal 1, @iron.reload.display_order
  end

  test "作業員は、品目を更新できない" do
    patch material_path(@iron),
          params: { material: { name: "テスト鉄くず" } },
          headers: auth_headers(@worker),
          as: :json

    assert_response :forbidden
    assert_equal "テスト鉄", @iron.reload.name
  end

  test "存在しない品目の更新は、404になる" do
    patch material_path(999_999),
          params: { material: { name: "テスト鉄くず" } },
          headers: auth_headers(@admin),
          as: :json

    assert_response :not_found
  end

  # --- 削除 ---

  test "管理者が削除すると、行は残したまま論理削除される" do
    assert_difference "Material.count", -1 do
      assert_no_difference "Material.with_deleted.count" do
        delete material_path(@iron), headers: auth_headers(@admin), as: :json
      end
    end

    assert_response :ok
    assert_equal "品目を削除しました", response.parsed_body["message"]
    assert_not_nil Material.with_deleted.find(@iron.id).deleted_at
  end

  test "作業員は、品目を削除できない" do
    assert_no_difference "Material.count" do
      delete material_path(@iron), headers: auth_headers(@worker), as: :json
    end

    assert_response :forbidden
  end
end
