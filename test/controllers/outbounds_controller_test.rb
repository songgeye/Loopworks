# frozen_string_literal: true

require "test_helper"

class OutboundsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = create_staff(role: "admin")
    @worker = create_staff(role: "staff")
    @counterparty = create_counterparty
    @material = create_material
    CurrentMaterial.create!(material: @material, quantity_kg: 10)
  end

  def create_outbound(quantity_kg: 3, **attributes)
    CreateOutbound.call(
      { counterparty: @counterparty, staff: @admin,
        outbounds_materials_attributes: [{ material_id: @material.id, quantity_kg: quantity_kg }] }
        .merge(attributes)
    )
  end

  def outbound_params(quantity_kg: 3, counterparty_id: @counterparty.id)
    {
      outbound: {
        counterparty_id: counterparty_id,
        staff_id: @admin.id,
        outbounds_materials_attributes: [{ material_id: @material.id, quantity_kg: quantity_kg }]
      }
    }
  end

  # --- 権限 ---

  test "ログインしていないと、401になる" do
    get outbounds_path, as: :json
    assert_response :unauthorized

    post outbounds_path, params: outbound_params, as: :json
    assert_response :unauthorized
  end

  test "作業員は、一覧・登録・取り消しのどれも403になる" do
    outbound = create_outbound
    headers = auth_headers(@worker)

    get outbounds_path, headers: headers, as: :json
    assert_response :forbidden
    assert_equal ["権限がありません"], response.parsed_body["errors"]

    assert_no_difference ["Outbound.count", "MaterialMovement.count"] do
      post outbounds_path, params: outbound_params, headers: headers, as: :json
      assert_response :forbidden

      delete outbound_path(outbound), params: { staff_id: @worker.id }, headers: headers, as: :json
      assert_response :forbidden
    end
  end

  # --- 一覧 ---

  test "管理者は一覧を見られ、数量はプラスで返る" do
    create_outbound(quantity_kg: 3, slip_no: "S-001")

    get outbounds_path, headers: auth_headers(@admin), as: :json

    assert_response :ok
    body = response.parsed_body
    assert_equal 1, body["total_count"]
    assert_equal 3, body["total_kg"]
    row = body["outbounds"].first
    assert_equal "S-001", row["slip_no"]
    assert_equal({ "id" => @counterparty.id, "name" => @counterparty.name }, row["counterparty"])
    assert_equal({ "id" => @admin.id, "name" => @admin.name }, row["staff"])
    assert_equal 3, row["total_kg"]
    assert_equal 3, row["items"].first["quantity_kg"]
    assert_equal false, row["cancelled"]
  end

  test "from と to で、期間を絞り込める(両端の日を含む)" do
    before = travel_to(Time.zone.local(2026, 11, 4, 23, 59)) { create_outbound(quantity_kg: 1) }
    first = travel_to(Time.zone.local(2026, 11, 5, 0, 0)) { create_outbound(quantity_kg: 1) }
    last = travel_to(Time.zone.local(2026, 11, 6, 23, 59)) { create_outbound(quantity_kg: 1) }
    after = travel_to(Time.zone.local(2026, 11, 7, 0, 0)) { create_outbound(quantity_kg: 1) }

    get outbounds_path, params: { from: "2026-11-05", to: "2026-11-06" }, headers: auth_headers(@admin)

    ids = response.parsed_body["outbounds"].map { |row| row["id"] }
    assert_equal [last.id, first.id], ids
    assert_not_includes ids, before.id
    assert_not_includes ids, after.id
  end

  test "日付の形式が正しくないと、422になる" do
    get outbounds_path, params: { to: "not-a-date" }, headers: auth_headers(@admin)

    assert_response :unprocessable_entity
    assert_match "日付の形式が正しくありません", response.parsed_body["errors"].first
  end

  test "取り消した出荷は一覧に残るが、件数と合計には含めない" do
    create_outbound(quantity_kg: 3)
    cancelled = create_outbound(quantity_kg: 5)
    CancelOutbound.call(outbound: cancelled, staff: @admin)

    get outbounds_path, headers: auth_headers(@admin), as: :json

    body = response.parsed_body
    assert_equal 2, body["outbounds"].size
    assert_equal 1, body["total_count"]
    assert_equal 3, body["total_kg"]
    assert_equal true, body["outbounds"].find { |row| row["id"] == cancelled.id }["cancelled"]
  end

  # --- 登録 ---

  test "出荷を登録すると、在庫が減る" do
    assert_difference ["Outbound.count", "MaterialMovement.count"], 1 do
      post outbounds_path, params: outbound_params(quantity_kg: 3), headers: auth_headers(@admin), as: :json
    end

    assert_response :created
    assert_empty response.parsed_body["warnings"]
    assert_equal 7, CurrentMaterial.find_by(material: @material).quantity_kg
    assert_equal(-3, MaterialMovement.last.quantity_kg)
  end

  test "在庫を超えて出荷すると、登録はされ、警告が返る" do
    post outbounds_path, params: outbound_params(quantity_kg: 12.5), headers: auth_headers(@admin), as: :json

    assert_response :created
    assert_equal [{ "material_id" => @material.id, "name" => @material.name, "shortage_kg" => 2.5 }],
                 response.parsed_body["warnings"]
    assert_equal(-2.5, CurrentMaterial.find_by(material: @material).quantity_kg)
  end

  test "存在しない取引先だと422が返り、何も保存されない" do
    assert_no_difference ["Outbound.count", "MaterialMovement.count"] do
      post outbounds_path,
           params: outbound_params(counterparty_id: 999_999),
           headers: auth_headers(@admin),
           as: :json
    end

    assert_response :unprocessable_entity
    assert_includes response.parsed_body["errors"], "Counterparty must exist"
    assert_equal 10, CurrentMaterial.find_by(material: @material).quantity_kg
  end

  # --- 取り消し ---

  test "出荷を取り消すと、在庫が元に戻る" do
    outbound = create_outbound(quantity_kg: 3)

    assert_difference "MaterialMovement.count", 1 do
      delete outbound_path(outbound), params: { staff_id: @admin.id }, headers: auth_headers(@admin), as: :json
    end

    assert_response :ok
    assert_equal outbound.id, response.parsed_body["id"]
    assert_equal 10, CurrentMaterial.find_by(material: @material).quantity_kg
    assert outbound.reload.cancelled?
  end

  test "すでに取り消した出荷を取り消すと、422になる" do
    outbound = create_outbound
    CancelOutbound.call(outbound: outbound, staff: @admin)

    assert_no_difference "MaterialMovement.count" do
      delete outbound_path(outbound), params: { staff_id: @admin.id }, headers: auth_headers(@admin), as: :json
    end

    assert_response :unprocessable_entity
    assert_equal ["すでに取り消し済みです"], response.parsed_body["errors"]
  end

  test "存在しない出荷を取り消すと、404になる" do
    delete outbound_path(999_999), params: { staff_id: @admin.id }, headers: auth_headers(@admin), as: :json

    assert_response :not_found
    assert_equal ["対象が見つかりません"], response.parsed_body["errors"]
  end
end
