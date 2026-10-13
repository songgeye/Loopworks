# frozen_string_literal: true
require "test_helper"
class OutboundsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @staff = Staff.create!(username: "test_admin", name: "テスト管理者", role: "admin", password: "password123")
    @counterparty = Counterparty.create!(party_type: :corporate, name: "テスト取引先")
    @material = Material.create!(name: "テスト鉄", display_order: 1)
    CurrentMaterial.create!(material: @material, quantity_kg: 10)
  end

  test "出荷を登録すると、在庫が減る" do
    assert_difference "MaterialMovement.count", 1 do
      post outbounds_path,
           params: {
             outbound: {
               counterparty_id: @counterparty.id,
               staff_id: @staff.id,
               outbounds_materials_attributes: [{ material_id: @material.id, quantity_kg: 3 }]
             }
           },
           as: :json
    end
    assert_response :created
    assert_equal 7, CurrentMaterial.find_by(material: @material).quantity_kg
    assert_equal(-3, MaterialMovement.last.quantity_kg)
  end

  test "存在しない取引先だと422が返り、何も保存されない" do
    assert_no_difference ["Outbound.count", "MaterialMovement.count"] do
      post outbounds_path,
           params: {
             outbound: {
               counterparty_id: 999_999,
               staff_id: @staff.id,
               outbounds_materials_attributes: [{ material_id: @material.id, quantity_kg: 3 }]
             }
           },
           as: :json
    end

    assert_response :unprocessable_entity
    assert_includes response.parsed_body["errors"], "Counterparty must exist"
    assert_equal 10, CurrentMaterial.find_by(material: @material).quantity_kg
  end
end
