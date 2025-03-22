require "test_helper"

class Api::V1::SpreadsControllerTest < ActionDispatch::IntegrationTest
  test "should get create" do
    # Convert positions to JSON string to match what the model expects
    positions = [
      { name: "past", description: "past influences" },
      { name: "present", description: "current situation" },
      { name: "future", description: "future outcome" }
    ]

    post api_v1_spreads_url, params: {
      spread: {
        name: "new spread",
        description: "test spread",
        positions: positions.to_json,
        is_public: true,
        user_id: users(:one).id
      }
    }
    assert_response :success
  end

  test "should get index" do
    get api_v1_spreads_url
    assert_response :success
  end

  test "should get show" do
    get api_v1_spread_url(spreads(:one))
    assert_response :success
  end
end
