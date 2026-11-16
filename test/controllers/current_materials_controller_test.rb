# frozen_string_literal: true

require "test_helper"

class CurrentMaterialsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @worker = create_staff(role: "staff")
  end

  test "ログインしていないと、401になる" do
    get current_materials_path, as: :json

    assert_response :unauthorized
  end

  test "品目ごとの現在庫を、表示順で返す" do
    copper = create_material(name: "テスト銅", display_order: 2)
    iron = create_material(name: "テスト鉄", display_order: 1)
    CurrentMaterial.create!(material: iron, quantity_kg: 12.5)
    CurrentMaterial.create!(material: copper, quantity_kg: -3)

    get current_materials_path, headers: auth_headers(@worker), as: :json

    assert_response :ok
    assert_equal [
      { "material_id" => iron.id, "name" => "テスト鉄", "quantity_kg" => 12.5, "stock_target" => true },
      { "material_id" => copper.id, "name" => "テスト銅", "quantity_kg" => -3.0, "stock_target" => true }
    ], response.parsed_body
  end

  test "現在庫の行がない品目は、0kgで返る" do
    material = create_material(stock_target: false)

    get current_materials_path, headers: auth_headers(@worker), as: :json

    assert_equal [
      { "material_id" => material.id, "name" => "テスト鉄", "quantity_kg" => 0.0, "stock_target" => false }
    ], response.parsed_body
  end

  test "削除した品目は、返さない" do
    create_material.destroy

    get current_materials_path, headers: auth_headers(@worker), as: :json

    assert_empty response.parsed_body
  end
end
