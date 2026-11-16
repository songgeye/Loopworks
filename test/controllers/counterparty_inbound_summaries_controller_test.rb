# frozen_string_literal: true

require "test_helper"

class CounterpartyInboundSummariesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = create_staff(role: "admin")
    @worker = create_staff(role: "staff")
  end

  test "ログインしていないと、401になる" do
    get counterparty_inbound_summaries_path, as: :json

    assert_response :unauthorized
  end

  test "作業員は、403になる" do
    get counterparty_inbound_summaries_path, headers: auth_headers(@worker), as: :json

    assert_response :forbidden
    assert_equal ["権限がありません"], response.parsed_body["errors"]
  end

  test "管理者は、取引先別の入荷集計を見られる" do
    counterparty = create_counterparty
    material = create_material
    CreateInbound.call(
      counterparty: counterparty,
      staff: @worker,
      inbounds_materials_attributes: [{ material_id: material.id, quantity_kg: 10.5 }]
    )

    get counterparty_inbound_summaries_path, headers: auth_headers(@admin), as: :json

    assert_response :ok
    assert_equal [
      { "counterparty_id" => counterparty.id, "name" => counterparty.name, "total_kg" => 10.5, "count" => 1 }
    ], response.parsed_body["summaries"]
  end

  test "入荷がなければ、空の集計が返る" do
    get counterparty_inbound_summaries_path, headers: auth_headers(@admin), as: :json

    assert_response :ok
    assert_empty response.parsed_body["summaries"]
  end
end
