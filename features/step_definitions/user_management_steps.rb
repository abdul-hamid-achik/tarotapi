When('i submit valid registration details') do
  @user_params = {
    email: 'test@example.com',
    password: 'secure_password123',
    password_confirmation: 'secure_password123',
    username: 'test_user'
  }
  
  post '/api/v1/users', user: @user_params
end

Then('a new user account should be created') do
  expect(json_response['data']['type']).to eq('user')
  expect(json_response['data']['attributes']['email']).to eq(@user_params[:email])
  expect(json_response['data']['attributes']['username']).to eq(@user_params[:username])
end

And('i should receive an authentication token') do
  expect(json_response['data']['attributes']['token']).not_to be_nil
end

Given('there is a registered user') do
  @user = create(:user,
    email: 'existing@example.com',
    password: 'existing_password123',
    username: 'existing_user'
  )
end

When('i submit valid login credentials') do
  post '/api/v1/auth/login', {
    email: @user.email,
    password: 'existing_password123'
  }
end

And('i should receive the user profile') do
  expect(json_response['data']['attributes']).to include(
    'email',
    'username',
    'created_at'
  )
end

Given('i am an authenticated user') do
  @user = create(:user)
  @auth_token = @user.generate_auth_token
  header 'authorization', "bearer #{@auth_token}"
end

When('i update my profile information') do
  @updated_params = {
    username: 'updated_username',
    email: 'updated@example.com'
  }
  
  put '/api/v1/users/profile', user: @updated_params
end

Then('my profile should be updated') do
  expect(json_response['data']['attributes']['username']).to eq(@updated_params[:username])
  expect(json_response['data']['attributes']['email']).to eq(@updated_params[:email])
end

And('i should see the updated information') do
  get '/api/v1/users/profile'
  expect(json_response['data']['attributes']['username']).to eq(@updated_params[:username])
  expect(json_response['data']['attributes']['email']).to eq(@updated_params[:email])
end

When('i submit a valid password change request') do
  @new_password = 'new_secure_password123'
  put '/api/v1/users/password', {
    current_password: 'existing_password123',
    password: @new_password,
    password_confirmation: @new_password
  }
end

Then('my password should be updated') do
  expect(response.status).to eq(200)
end

And('i should be able to login with the new password') do
  post '/api/v1/auth/login', {
    email: @user.email,
    password: @new_password
  }
  expect(json_response['data']['attributes']['token']).not_to be_nil
end

When('i request a password reset') do
  post '/api/v1/auth/password/reset', {
    email: @user.email
  }
end

Then('a password reset token should be generated') do
  expect(response.status).to eq(200)
  @user.reload
  expect(@user.reset_password_token).not_to be_nil
end

And('a reset email should be sent') do
  expect(ActionMailer::Base.deliveries.last.to).to include(@user.email)
end

Given('there is a valid password reset token') do
  @user = create(:user)
  @reset_token = @user.generate_reset_token
end

When('i submit the reset token') do
  get "/api/v1/auth/password/reset/#{@reset_token}"
end

Then('the token should be validated') do
  expect(response.status).to eq(200)
end

And('i should be allowed to set a new password') do
  put "/api/v1/auth/password/reset/#{@reset_token}", {
    password: 'new_password123',
    password_confirmation: 'new_password123'
  }
  expect(response.status).to eq(200)
end

And('i have previous readings') do
  @readings = create_list(:reading_session, 3, user: @user)
end

When('i request my reading history') do
  get '/api/v1/users/readings'
end

Then('i should receive a list of my past readings') do
  expect(json_response['data']).to be_an(Array)
  expect(json_response['data'].length).to eq(@readings.length)
  expect(json_response['data'].first['type']).to eq('reading_session')
end 