# frozen_string_literal: true

require "test_helper"

class CounterpartyInboundSummaryTest < ActiveSupport::TestCase
  setup do
    @staff = create_staff(role: "admin")
    @iron = create_material(name: "テスト鉄", display_order: 1)
    @copper = create_material(name: "テスト銅", display_order: 2)
    @small = create_counterparty(name: "少ない取引先")
    @large = create_counterparty(name: "多い取引先")
  end

  def create_inbound(counterparty, items)
    CreateInbound.call(counterparty: counterparty, staff: @staff, inbounds_materials_attributes: items)
  end

  test "入荷がなければ、空で返る" do
    assert_empty CounterpartyInboundSummary.call
  end

  test "取引先ごとに、重量の合計と入荷の件数を返す" do
    create_inbound(@small, [{ material_id: @iron.id, quantity_kg: 10 }])
    create_inbound(@small, [{ material_id: @copper.id, quantity_kg: 2.5 }])

    assert_equal [{ counterparty_id: @small.id, name: "少ない取引先", total_kg: 12.5, count: 2 }],
                 CounterpartyInboundSummary.call
  end

  test "1件の入荷に明細が複数あっても、件数は1件と数える" do
    create_inbound(@small, [
      { material_id: @iron.id, quantity_kg: 10 },
      { material_id: @copper.id, quantity_kg: 5 }
    ])

    summary = CounterpartyInboundSummary.call.first

    assert_equal 15, summary[:total_kg]
    assert_equal 1, summary[:count]
  end

  test "重量の合計が多い取引先から順に並ぶ" do
    create_inbound(@small, [{ material_id: @iron.id, quantity_kg: 10 }])
    create_inbound(@large, [{ material_id: @iron.id, quantity_kg: 100 }])

    assert_equal ["多い取引先", "少ない取引先"], CounterpartyInboundSummary.call.map { |row| row[:name] }
  end

  test "取り消した入荷は、集計に含めない" do
    create_inbound(@small, [{ material_id: @iron.id, quantity_kg: 10 }])
    cancelled = create_inbound(@small, [{ material_id: @iron.id, quantity_kg: 99 }])
    CancelInbound.call(inbound: cancelled, staff: @staff)

    assert_equal [{ counterparty_id: @small.id, name: "少ない取引先", total_kg: 10.0, count: 1 }],
                 CounterpartyInboundSummary.call
  end

  test "入荷をすべて取り消した取引先は、集計に出ない" do
    cancelled = create_inbound(@small, [{ material_id: @iron.id, quantity_kg: 10 }])
    CancelInbound.call(inbound: cancelled, staff: @staff)

    assert_empty CounterpartyInboundSummary.call
  end

  test "出荷と在庫調整は、集計に含めない" do
    create_inbound(@small, [{ material_id: @iron.id, quantity_kg: 10 }])
    CreateOutbound.call(
      counterparty: @large,
      staff: @staff,
      outbounds_materials_attributes: [{ material_id: @iron.id, quantity_kg: 3 }]
    )
    CreateAdjustment.call(
      material_id: @iron.id, staff_id: @staff.id, direction: "increase", quantity_kg: 50, note: "棚卸差異"
    )

    assert_equal [{ counterparty_id: @small.id, name: "少ない取引先", total_kg: 10.0, count: 1 }],
                 CounterpartyInboundSummary.call
  end
end
