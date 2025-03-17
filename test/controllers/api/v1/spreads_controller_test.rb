require "test_helper"

class Api::V1::SpreadsControllerTest < ActionDispatch::IntegrationTest
  test "should get create" do
    post api_v1_spreads_url, params: { spread: { name: "new spread", description: "test spread", positions: 3, is_public: true } }
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
