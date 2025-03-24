require "test_helper"

class Api::V1::TarotCardsControllerTest < ActionDispatch::IntegrationTest
  mock_pundit

  test "should get index" do
    get api_v1_cards_url
    assert_response :success

    json_response = JSON.parse(response.body)
    assert_not_nil json_response["data"]
    assert_kind_of Array, json_response["data"]
  end

  test "should get show" do
    get api_v1_card_url(cards(:one))
    assert_response :success

    json_response = JSON.parse(response.body)
    assert_not_nil json_response["data"]
    assert_equal cards(:one).id.to_s, json_response["data"]["id"]
  end

  test "should return not found for invalid card id" do
    get api_v1_card_url(999999)
    assert_response :not_found

    json_response = JSON.parse(response.body)
    assert_equal "card not found", json_response["error"]
  end
end
