# frozen_string_literal: true

require "active_support/testing/time_helpers"

abort "本番では ALLOW_DEMO_SEED=1 を付けたときだけ実行できます" if Rails.env.production? && ENV["ALLOW_DEMO_SEED"] != "1"
abort "すでに入出庫のデータがあります。先に demo_reset.rb を実行してください" if Inbound.exists? || Outbound.exists?

class DemoSeed
  include ActiveSupport::Testing::TimeHelpers

  SEED = 20_261_116
  PASSWORD = ENV.fetch("DEMO_PASSWORD", "123456")

  ADMIN_NAME = "村上 直樹"
  STAFFS = [
    { username: "tanaka", name: "田中 悠斗", role: "staff" },
    { username: "suzuki", name: "鈴木 美咲", role: "staff" },
    { username: "takahashi", name: "高橋 大輔", role: "staff" },
    { username: "ito", name: "伊藤 和也", role: "staff" }
  ].freeze

  MATERIALS = [ "鉄(ヘビー)", "鉄(軽量)", "銅(ピカ線)", "アルミ(サッシ)", "ステンレス", "真鍮" ].freeze
  RANGES = {
    "鉄(ヘビー)" => 300..1800, "鉄(軽量)" => 200..1200, "銅(ピカ線)" => 20..150,
    "アルミ(サッシ)" => 50..400, "ステンレス" => 40..300, "真鍮" => 10..100
  }.freeze

  SUPPLIERS = [
    { name: "東和金属工業株式会社", type: :corporate, weight: 4, scale: 1.0, pics: %w[山口 小川],
      materials: [ "鉄(軽量)", "ステンレス", "真鍮" ] },
    { name: "有限会社大洋解体", type: :corporate, weight: 5, scale: 1.2, pics: %w[岡田 森],
      materials: [ "鉄(ヘビー)", "鉄(軽量)", "アルミ(サッシ)" ] },
    { name: "株式会社栄進建設", type: :corporate, weight: 4, scale: 1.1, pics: %w[近藤],
      materials: [ "鉄(ヘビー)", "アルミ(サッシ)" ] },
    { name: "北斗設備工業株式会社", type: :corporate, weight: 3, scale: 1.0, pics: %w[石井 松本],
      materials: [ "銅(ピカ線)", "アルミ(サッシ)", "ステンレス" ] },
    { name: "株式会社丸三運輸", type: :corporate, weight: 2, scale: 0.8, pics: %w[藤田],
      materials: [ "鉄(ヘビー)", "鉄(軽量)" ] },
    { name: "川島電機有限会社", type: :corporate, weight: 2, scale: 0.7, pics: %w[川島],
      materials: [ "銅(ピカ線)", "ステンレス", "真鍮" ] },
    { name: "小林 茂", type: :individual, weight: 1, scale: 0.15, pics: [],
      materials: [ "銅(ピカ線)", "真鍮", "アルミ(サッシ)" ] },
    { name: "渡辺 洋子", type: :individual, weight: 1, scale: 0.12, pics: [],
      materials: [ "真鍮", "アルミ(サッシ)" ] },
    { name: "中村 誠", type: :individual, weight: 1, scale: 0.2, pics: [],
      materials: [ "銅(ピカ線)", "鉄(軽量)" ] }
  ].freeze

  BUYERS = [
    { name: "日の出製鋼株式会社", type: :corporate, pics: %w[安田], handles: [ "鉄(ヘビー)", "鉄(軽量)" ] },
    { name: "西日本非鉄販売株式会社", type: :corporate, pics: %w[竹内], handles: [ "銅(ピカ線)", "真鍮", "ステンレス" ] },
    { name: "関東メタルリサイクル株式会社", type: :corporate, pics: %w[内田], handles: [ "アルミ(サッシ)" ] }
  ].freeze
  OUTBOUND_DAYS = [ -27, -21, -15, -9, -4 ].freeze
  OUTBOUND_BUYERS = [ 0, 1, 0, 2, 1 ].freeze

  ADJUSTMENTS = [
    { offset: -12, material: "鉄(軽量)", direction: "decrease", kg: 38.0, note: "棚卸しで、実在庫が帳簿より少なかったため" },
    { offset: -6, material: "銅(ピカ線)", direction: "increase", kg: 4.5, note: "入庫時の計量漏れが見つかったため" }
  ].freeze

  def run
    ActiveRecord::Base.transaction do
      create_masters
      play(plan_events)
    end
    report
  end

  private

  def create_masters
    @admin = Staff.find_by(username: "admin") || Staff.new(username: "admin", role: "admin", password: PASSWORD)
    @admin.name = ADMIN_NAME
    @admin.save!
    @staffs = STAFFS.map { |attrs| Staff.create!(attrs.merge(password: PASSWORD)) }
    MATERIALS.each_with_index { |name, i| Material.create!(name: name, display_order: i + 1) }
    @materials = Material.all.index_by(&:name)
    (SUPPLIERS + BUYERS).each { |attrs| Counterparty.create!(party_type: attrs[:type], name: attrs[:name]) }
    @counterparties = Counterparty.all.index_by(&:name)
  end

  def plan_events
    rng = Random.new(SEED)
    today = Date.current
    now = Time.zone.now
    events = []

    ((today - 29)..today).each do |date|
      next if date.sunday?
      rng.rand(2..3).times do
        at = Time.zone.local(date.year, date.month, date.day, rng.rand(8..16), rng.rand(0..59))
        supplier = pick_weighted(SUPPLIERS, rng)
        event = { kind: :inbound, at: at, supplier: supplier, items: build_items(supplier, rng),
                  staff: @staffs.sample(random: rng), pic: supplier[:pics].sample(random: rng) }
        events << event if at <= now
      end
    end

    OUTBOUND_DAYS.each_with_index do |offset, i|
      date = today + offset
      date -= 1 if date.sunday?
      at = Time.zone.local(date.year, date.month, date.day, 14, rng.rand(0..50))
      buyer = BUYERS[OUTBOUND_BUYERS[i]]
      events << { kind: :outbound, at: at, buyer: buyer, staff: @staffs.sample(random: rng),
                  pic: buyer[:pics].first } if at <= now
    end

    ADJUSTMENTS.each do |adj|
      date = today + adj[:offset]
      events << adj.merge(kind: :adjustment, at: Time.zone.local(date.year, date.month, date.day, 17, 30))
    end
    events
  end

  def build_items(supplier, rng)
    count = [ rng.rand(1..3), supplier[:materials].size ].min
    supplier[:materials].shuffle(random: rng).first(count).map do |name|
      raw = [ rng.rand(RANGES.fetch(name)) * supplier[:scale], 2.0 ].max
      actual = round_to(raw, raw >= 100 ? 5 : 0.5)
      ratio = rng.rand < 0.07 ? rng.rand(0.85..0.89) : rng.rand(0.94..1.06)
      step = actual >= 200 ? 10 : (actual >= 20 ? 5 : 1)
      { name: name, actual: actual, declared: round_to([ actual * ratio, 2.0 ].max, step) }
    end
  end

  def pick_weighted(list, rng)
    r = rng.rand * list.sum { |x| x[:weight] }
    list.each { |x| return x if (r -= x[:weight]) <= 0 }
    list.last
  end

  def round_to(value, step)
    ((value / step.to_f).round * step).to_f
  end

  def play(events)
    @stock = Hash.new(0.0)
    @slip = Hash.new(0)
    @rng = Random.new(SEED + 1)
    events.sort_by { |e| e[:at] }.each do |e|
      travel_to(e[:at]) do
        case e[:kind]
        when :inbound then record_inbound(e)
        when :outbound then record_outbound(e)
        when :adjustment then record_adjustment(e)
        end
      end
    end
  end

  def record_inbound(e)
    date = e[:at].to_date
    @slip[[ :in, date ]] += 1
    CreateInbound.call(
      counterparty_id: @counterparties.fetch(e[:supplier][:name]).id,
      staff_id: e[:staff].id,
      counterparty_pic_name: e[:pic],
      slip_no: format("IN%s-%02d", date.strftime("%m%d"), @slip[[ :in, date ]]),
      inbounds_materials_attributes: e[:items].map do |i|
        { material_id: @materials.fetch(i[:name]).id, quantity_kg: i[:actual], declared_kg: i[:declared] }
      end
    )
    e[:items].each { |i| @stock[i[:name]] += i[:actual] }
  end

  def record_outbound(e)
    items = e[:buyer][:handles].filter_map do |name|
      next if @stock[name] < 200
      { name: name, kg: round_to(@stock[name] * @rng.rand(0.55..0.75), 10) }
    end
    return if items.empty?

    date = e[:at].to_date
    @slip[[ :out, date ]] += 1
    CreateOutbound.call(
      counterparty_id: @counterparties.fetch(e[:buyer][:name]).id,
      staff_id: e[:staff].id,
      counterparty_pic_name: e[:pic],
      slip_no: format("OUT%s-%02d", date.strftime("%m%d"), @slip[[ :out, date ]]),
      outbounds_materials_attributes: items.map { |i| { material_id: @materials.fetch(i[:name]).id, quantity_kg: i[:kg] } }
    )
    items.each { |i| @stock[i[:name]] -= i[:kg] }
  end

  def record_adjustment(e)
    return if e[:direction] == "decrease" && @stock[e[:material]] < e[:kg]

    CreateAdjustment.call(
      material_id: @materials.fetch(e[:material]).id, staff_id: @admin.id,
      direction: e[:direction], quantity_kg: e[:kg], note: e[:note]
    )
    @stock[e[:material]] += e[:direction] == "increase" ? e[:kg] : -e[:kg]
  end

  def report
    puts "スタッフ #{Staff.count}人 / 品目 #{Material.count}件 / 取引先 #{Counterparty.count}件"
    puts "入庫 #{Inbound.count}件 / 出庫 #{Outbound.count}件 / 在庫調整 #{AdjustmentMaterial.count}件"
    Material.order(:display_order).each do |m|
      puts "  #{m.name}: #{m.current_material&.quantity_kg.to_f} kg"
    end
  end
end

DemoSeed.new.run
