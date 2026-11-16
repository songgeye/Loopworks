# frozen_string_literal: true

require "test_helper"

class InboundsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = create_staff(role: "admin")
    @worker = create_staff(role: "staff")
    @counterparty = create_counterparty
    @material = create_material
  end

  def create_inbound(quantity_kg: 10, staff: @worker, **attributes)
    CreateInbound.call(
      { counterparty: @counterparty, staff: staff,
        inbounds_materials_attributes: [{ material_id: @material.id, quantity_kg: quantity_kg }] }
        .merge(attributes)
    )
  end

  # --- 一覧 ---

  test "ログインしていないと、一覧は401になる" do
    get inbounds_path, as: :json

    assert_response :unauthorized
  end

  test "作業員も、一覧を見られる" do
    create_inbound(slip_no: "S-001", counterparty_pic_name: "担当者")

    get inbounds_path, headers: auth_headers(@worker), as: :json

    assert_response :ok
    body = response.parsed_body
    assert_equal 1, body["total_count"]
    assert_equal 10, body["total_kg"]
    row = body["inbounds"].first
    assert_equal "S-001", row["slip_no"]
    assert_equal "担当者", row["counterparty_pic_name"]
    assert_equal({ "id" => @counterparty.id, "name" => @counterparty.name }, row["counterparty"])
    assert_equal({ "id" => @worker.id, "name" => @worker.name }, row["staff"])
    assert_equal 10, row["total_kg"]
    assert_equal false, row["cancelled"]
    assert_equal true, row["editable"]
    assert_equal @material.id, row["items"].first["material_id"]
    assert_equal @material.name, row["items"].first["material_name"]
    assert_equal 10, row["items"].first["quantity_kg"]
    assert_nil row["items"].first["declared_kg"]
  end

  test "一覧は、新しい順に並ぶ" do
    old = travel_to(Time.zone.local(2026, 11, 5, 10, 0)) { create_inbound }
    new = travel_to(Time.zone.local(2026, 11, 6, 10, 0)) { create_inbound }

    get inbounds_path, headers: auth_headers(@admin), as: :json

    assert_equal [new.id, old.id], response.parsed_body["inbounds"].map { |row| row["id"] }
  end

  test "from と to で、期間を絞り込める(両端の日を含む)" do
    before = travel_to(Time.zone.local(2026, 11, 4, 23, 59)) { create_inbound }
    first = travel_to(Time.zone.local(2026, 11, 5, 0, 0)) { create_inbound }
    last = travel_to(Time.zone.local(2026, 11, 6, 23, 59)) { create_inbound }
    after = travel_to(Time.zone.local(2026, 11, 7, 0, 0)) { create_inbound }

    get inbounds_path, params: { from: "2026-11-05", to: "2026-11-06" }, headers: auth_headers(@admin)

    ids = response.parsed_body["inbounds"].map { |row| row["id"] }
    assert_equal [last.id, first.id], ids
    assert_not_includes ids, before.id
    assert_not_includes ids, after.id
  end

  test "from だけ、to だけでも絞り込める" do
    old = travel_to(Time.zone.local(2026, 11, 5, 10, 0)) { create_inbound }
    new = travel_to(Time.zone.local(2026, 11, 6, 10, 0)) { create_inbound }
    headers = auth_headers(@admin)

    get inbounds_path, params: { from: "2026-11-06" }, headers: headers
    assert_equal [new.id], response.parsed_body["inbounds"].map { |row| row["id"] }

    get inbounds_path, params: { to: "2026-11-05" }, headers: headers
    assert_equal [old.id], response.parsed_body["inbounds"].map { |row| row["id"] }
  end

  test "日付の形式が正しくないと、422になる" do
    get inbounds_path, params: { from: "2026/11/06" }, headers: auth_headers(@admin)

    assert_response :unprocessable_entity
    assert_match "日付の形式が正しくありません", response.parsed_body["errors"].first
  end

  test "取り消した入荷は一覧に残るが、件数と合計には含めない" do
    create_inbound(quantity_kg: 10)
    cancelled = create_inbound(quantity_kg: 99)
    CancelInbound.call(inbound: cancelled, staff: @admin)

    get inbounds_path, headers: auth_headers(@admin), as: :json

    body = response.parsed_body
    assert_equal 2, body["inbounds"].size
    assert_equal 1, body["total_count"]
    assert_equal 10, body["total_kg"]
    assert_equal true, body["inbounds"].find { |row| row["id"] == cancelled.id }["cancelled"]
  end

  test "過去の営業日の入荷は、作業員には編集不可・管理者には編集可で返る" do
    travel_to(Time.zone.local(2026, 11, 5, 10, 0)) { create_inbound }

    travel_to Time.zone.local(2026, 11, 6, 10, 0) do
      get inbounds_path, headers: auth_headers(@worker), as: :json
      assert_equal false, response.parsed_body["inbounds"].first["editable"]

      get inbounds_path, headers: auth_headers(@admin), as: :json
      assert_equal true, response.parsed_body["inbounds"].first["editable"]
    end
  end

  # --- 登録 ---

  test "ログインしていないと、登録は401になり何も保存されない" do
    assert_no_difference ["Inbound.count", "MaterialMovement.count"] do
      post inbounds_path,
           params: {
             inbound: {
               counterparty_id: @counterparty.id,
               staff_id: @worker.id,
               inbounds_materials_attributes: [{ material_id: @material.id, quantity_kg: 10 }]
             }
           },
           as: :json
    end

    assert_response :unauthorized
  end

  test "入荷を登録できる" do
    assert_difference ["Inbound.count", "MaterialMovement.count"], 1 do
      post inbounds_path,
           params: {
             inbound: {
               counterparty_id: @counterparty.id,
               staff_id: @worker.id,
               counterparty_pic_name: "担当者",
               slip_no: "S-001",
               inbounds_materials_attributes: [{ material_id: @material.id, quantity_kg: 10, declared_kg: 10.5 }]
             }
           },
           headers: auth_headers(@worker),
           as: :json
    end

    assert_response :created
    inbound = Inbound.find(response.parsed_body["id"])
    assert_equal "担当者", inbound.counterparty_pic_name
    assert_equal "S-001", inbound.slip_no
    assert_equal 10.5, inbound.inbounds_materials.first.declared_kg
    assert_equal 10, CurrentMaterial.find_by(material: @material).quantity_kg
  end

  test "存在しない取引先だと422が返り、何も保存されない" do
    assert_no_difference ["Inbound.count", "MaterialMovement.count"] do
      post inbounds_path,
           params: {
             inbound: {
               counterparty_id: 999_999,
               staff_id: @worker.id,
               inbounds_materials_attributes: [{ material_id: @material.id, quantity_kg: 10 }]
             }
           },
           headers: auth_headers(@worker),
           as: :json
    end

    assert_response :unprocessable_entity
    assert_includes response.parsed_body["errors"], "Counterparty must exist"
  end

  # --- 取り消し ---

  test "作業員は、当日の入荷を取り消せる" do
    inbound = create_inbound

    assert_difference "MaterialMovement.count", 1 do
      delete inbound_path(inbound), params: { staff_id: @worker.id }, headers: auth_headers(@worker), as: :json
    end

    assert_response :ok
    assert_equal inbound.id, response.parsed_body["id"]
    assert_empty response.parsed_body["warnings"]
    assert_equal 0, CurrentMaterial.find_by(material: @material).quantity_kg
    assert inbound.reload.cancelled?
  end

  test "作業員は、過去の営業日の入荷を取り消せない" do
    inbound = travel_to(Time.zone.local(2026, 11, 5, 10, 0)) { create_inbound }

    travel_to Time.zone.local(2026, 11, 6, 10, 0) do
      assert_no_difference "MaterialMovement.count" do
        delete inbound_path(inbound), params: { staff_id: @worker.id }, headers: auth_headers(@worker), as: :json
      end
    end

    assert_response :forbidden
    assert_equal ["権限がありません"], response.parsed_body["errors"]
    assert_equal 10, CurrentMaterial.find_by(material: @material).quantity_kg
  end

  test "管理者は、過去の営業日の入荷も取り消せる" do
    inbound = travel_to(Time.zone.local(2026, 11, 5, 10, 0)) { create_inbound }

    travel_to Time.zone.local(2026, 11, 6, 10, 0) do
      delete inbound_path(inbound), params: { staff_id: @admin.id }, headers: auth_headers(@admin), as: :json
    end

    assert_response :ok
    assert inbound.reload.cancelled?
  end

  test "取り消しで在庫がマイナスになると、警告が返る" do
    inbound = create_inbound(quantity_kg: 10)
    CreateOutbound.call(
      counterparty: @counterparty,
      staff: @admin,
      outbounds_materials_attributes: [{ material_id: @material.id, quantity_kg: 8 }]
    )

    delete inbound_path(inbound), params: { staff_id: @admin.id }, headers: auth_headers(@admin), as: :json

    assert_response :ok
    assert_equal [{ "material_id" => @material.id, "name" => @material.name, "shortage_kg" => 8.0 }],
                 response.parsed_body["warnings"]
  end

  test "すでに取り消した入荷を取り消すと、422になる" do
    inbound = create_inbound
    CancelInbound.call(inbound: inbound, staff: @admin)

    assert_no_difference "MaterialMovement.count" do
      delete inbound_path(inbound), params: { staff_id: @admin.id }, headers: auth_headers(@admin), as: :json
    end

    assert_response :unprocessable_entity
    assert_equal ["すでに取り消し済みです"], response.parsed_body["errors"]
  end

  test "存在しない入荷を取り消すと、404になる" do
    delete inbound_path(999_999), params: { staff_id: @admin.id }, headers: auth_headers(@admin), as: :json

    assert_response :not_found
    assert_equal ["対象が見つかりません"], response.parsed_body["errors"]
  end

  test "存在しないスタッフを指定して取り消すと、404になり在庫は変わらない" do
    inbound = create_inbound

    delete inbound_path(inbound), params: { staff_id: 999_999 }, headers: auth_headers(@admin), as: :json

    assert_response :not_found
    assert_equal 10, CurrentMaterial.find_by(material: @material).quantity_kg
  end

  test "ログインしていないと、取り消しは401になる" do
    inbound = create_inbound

    delete inbound_path(inbound), params: { staff_id: @admin.id }, as: :json

    assert_response :unauthorized
    assert_not inbound.reload.cancelled?
  end
end
