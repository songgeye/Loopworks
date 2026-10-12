# frozen_string_literal: true
require "test_helper"
class InboundsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @staff = Staff.create!(username: "test_admin", name: "テスト管理者", role: "admin", password: "password123")
    @counterparty = Counterparty.create!(party_type: :corporate, name: "テスト取引先")
    @material = Material.create!(name: "テスト鉄", display_order: 1)
  end

  test "入荷を登録できる" do
    assert_difference ["Inbound.count", "MaterialMovement.count"], 1 do
      post inbounds_path,
           params: {
             inbound: {
               counterparty_id: @counterparty.id,
               staff_id: @staff.id,
               recorded_at: Time.zone.now,
               inbounds_materials_attributes: [{ material_id: @material.id, quantity_kg: 10 }]
             }
           },
           as: :json
    end
    assert_response :created
    assert_equal 10, CurrentMaterial.find_by(material: @material).quantity_kg
  end

  test "存在しない取引先だと422が返り、何も保存されない" do
    assert_no_difference ["Inbound.count", "MaterialMovement.count"] do
      post inbounds_path,
           params: {
             inbound: {
               counterparty_id: 999_999,
               staff_id: @staff.id,
               recorded_at: Time.zone.now,
               inbounds_materials_attributes: [{ material_id: @material.id, quantity_kg: 10 }]
             }
           },
           as: :json
    end

    assert_response :unprocessable_entity
    assert_includes response.parsed_body["errors"], "Counterparty must exist"
  end

  end
