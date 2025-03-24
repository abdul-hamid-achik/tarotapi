require "test_helper"

class Api::V1::UsersControllerTest < ActionDispatch::IntegrationTest
  mock_pundit

  test "should get create" do
    post api_v1_users_url, params: { user: { email: "test@example.com", password: "password123" } }
    assert_response :success
  end

  test "should get show" do
    get api_v1_user_url(users(:one))
    assert_response :success
  end
end
