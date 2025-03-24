require "test_helper"

class Api::V1::CardReadingsControllerTest < ActionDispatch::IntegrationTest
  mock_pundit

  test "should create card reading with registered user" do
    post api_v1_card_readings_url, params: {
      email: users(:one).email,
      tarot_card_id: tarot_cards(:one).id,
      spread_id: spreads(:one).id,
      question: "what's my future?",
      position: 1,
      is_reversed: false,
      notes: "test reading"
    }
    assert_response :success
    assert_equal 1, json_response["position"]
  end

  test "should create card reading with anonymous user" do
    post api_v1_card_readings_url, params: {
      external_id: users(:anonymous).external_id,
      provider: "anonymous",
      tarot_card_id: tarot_cards(:one).id,
      spread_id: spreads(:one).id,
      question: "what's my future?",
      position: 2,
      is_reversed: false,
      notes: "test reading"
    }
    assert_response :success
    assert_equal 2, json_response["position"]
  end

  test "should create card reading with agent" do
    post api_v1_card_readings_url, params: {
      external_id: users(:agent).external_id,
      provider: "agent",
      tarot_card_id: tarot_cards(:one).id,
      spread_id: spreads(:one).id,
      question: "what's my future?",
      position: 3,
      is_reversed: false,
      notes: "test reading"
    }
    assert_response :success
    assert_equal 3, json_response["position"]
  end

  test "should get index for registered user" do
    get api_v1_card_readings_url, params: { email: users(:one).email }
    assert_response :success
  end

  test "should get index for anonymous user" do
    get api_v1_card_readings_url, params: { external_id: users(:anonymous).external_id }
    assert_response :success
  end

  test "should get show" do
    get api_v1_card_reading_url(card_readings(:one))
    assert_response :success
  end

  private

  def json_response
    JSON.parse(response.body)
  end
end
