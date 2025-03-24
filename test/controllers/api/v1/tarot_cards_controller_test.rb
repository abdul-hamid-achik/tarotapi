require "test_helper"

class Api::V1::TarotCardsControllerTest < ActionDispatch::IntegrationTest
  mock_pundit

  setup do
    @user = users(:one) || User.create!(email: "test-user@example.com", password: "password")
    @auth_headers = {
      "Authorization" => "Bearer test_token",
      "Content-Type" => "application/json"
    }
  end

  test "should get index" do
    get api_v1_cards_url, headers: @auth_headers
    assert_response :success

    json_response = JSON.parse(response.body)
    assert_not_nil json_response["data"]
    assert_kind_of Array, json_response["data"]
  end

  test "should get show" do
    get api_v1_card_url(cards(:one)), headers: @auth_headers
    assert_response :success

    json_response = JSON.parse(response.body)
    assert_not_nil json_response["data"]
    assert_equal cards(:one).id.to_s, json_response["data"]["id"]
  end

  test "should return not found for invalid card id" do
    get api_v1_card_url(999999), headers: @auth_headers
    assert_response :not_found

    json_response = JSON.parse(response.body)
    assert_equal "card not found", json_response["error"]
  end
end
