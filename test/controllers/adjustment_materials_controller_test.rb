# frozen_string_literal: true

require "test_helper"

class AdjustmentMaterialsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = create_staff(role: "admin")
    @worker = create_staff(role: "staff")
    @material = create_material
    CurrentMaterial.create!(material: @material, quantity_kg: 10)
  end

  def adjustment_params(**overrides)
    {
      adjustment_material: {
        material_id: @material.id, staff_id: @admin.id, direction: "increase", quantity_kg: 5, note: "棚卸差異"
      }.merge(overrides)
    }
  end

  test "ログインしていないと、401になる" do
    assert_no_difference "AdjustmentMaterial.count" do
      post adjustment_materials_path, params: adjustment_params, as: :json
    end

    assert_response :unauthorized
  end

  test "作業員は、403になり何も保存されない" do
    assert_no_difference ["AdjustmentMaterial.count", "MaterialMovement.count"] do
      post adjustment_materials_path, params: adjustment_params, headers: auth_headers(@worker), as: :json
    end

    assert_response :forbidden
    assert_equal ["権限がありません"], response.parsed_body["errors"]
  end

  test "管理者は、在庫を増やす調整ができる" do
    assert_difference ["AdjustmentMaterial.count", "MaterialMovement.count"], 1 do
      post adjustment_materials_path,
           params: adjustment_params(direction: "increase", quantity_kg: 5),
           headers: auth_headers(@admin),
           as: :json
    end

    assert_response :created
    assert_equal AdjustmentMaterial.last.id, response.parsed_body["id"]
    assert_empty response.parsed_body["warnings"]
    assert_equal 15, CurrentMaterial.find_by(material: @material).quantity_kg
  end

  test "管理者は、在庫を減らす調整ができる" do
    post adjustment_materials_path,
         params: adjustment_params(direction: "decrease", quantity_kg: 4),
         headers: auth_headers(@admin),
         as: :json

    assert_response :created
    assert_equal 6, CurrentMaterial.find_by(material: @material).quantity_kg
  end

  test "調整で在庫がマイナスになると、警告が返る" do
    post adjustment_materials_path,
         params: adjustment_params(direction: "decrease", quantity_kg: 12),
         headers: auth_headers(@admin),
         as: :json

    assert_response :created
    assert_equal [{ "material_id" => @material.id, "name" => @material.name, "shortage_kg" => 2.0 }],
                 response.parsed_body["warnings"]
  end

  test "区分が正しくないと、422になり何も保存されない" do
    assert_no_difference ["AdjustmentMaterial.count", "MaterialMovement.count"] do
      post adjustment_materials_path,
           params: adjustment_params(direction: "unknown"),
           headers: auth_headers(@admin),
           as: :json
    end

    assert_response :unprocessable_entity
    assert_equal ["区分が正しくありません"], response.parsed_body["errors"]
  end

  test "理由がないと、422になり何も保存されない" do
    assert_no_difference ["AdjustmentMaterial.count", "MaterialMovement.count"] do
      post adjustment_materials_path,
           params: adjustment_params(note: ""),
           headers: auth_headers(@admin),
           as: :json
    end

    assert_response :unprocessable_entity
    assert_includes response.parsed_body["errors"], "Note can't be blank"
    assert_equal 10, CurrentMaterial.find_by(material: @material).quantity_kg
  end
end
