ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...

    # テスト用のスタッフを作る。username は連番で重複を避ける
    def create_staff(role: "staff", **attributes)
      @staff_sequence = (@staff_sequence || 0) + 1
      Staff.create!({
        username: "test_#{role}_#{@staff_sequence}",
        name: "テスト#{role == 'admin' ? '管理者' : '作業員'}#{@staff_sequence}",
        role: role,
        password: "password123"
      }.merge(attributes))
    end

    def create_counterparty(**attributes)
      Counterparty.create!({ party_type: :corporate, name: "テスト取引先" }.merge(attributes))
    end

    def create_material(name: "テスト鉄", display_order: 1, **attributes)
      Material.create!({ name: name, display_order: display_order }.merge(attributes))
    end

    # 締め時刻(BUSINESS_DAY_CUTOFF_HOUR)を、ブロックの中だけ差し替える
    def with_cutoff_hour(hour)
      original = BUSINESS_DAY_CUTOFF_HOUR
      silence_warnings { Object.const_set(:BUSINESS_DAY_CUTOFF_HOUR, hour) }
      yield
    ensure
      silence_warnings { Object.const_set(:BUSINESS_DAY_CUTOFF_HOUR, original) }
    end
  end
end

module ActionDispatch
  class IntegrationTest
    # 実際にログインして、JWT入りの Authorization ヘッダーを返す
    def auth_headers(staff, password: "password123")
      post staff_session_path,
           params: { staff: { username: staff.username, password: password } },
           as: :json
      assert_response :ok, "テスト用スタッフのログインに失敗しました"
      { "Authorization" => response.headers["Authorization"] }
    end
  end
end
