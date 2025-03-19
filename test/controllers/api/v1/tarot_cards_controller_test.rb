require "test_helper"

class Api::V1::TarotCardsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get api_v1_tarot_cards_url
    assert_response :success
  end

  test "should get show" do
    get api_v1_tarot_card_url(tarot_cards(:one))
    assert_response :success
  end
end
