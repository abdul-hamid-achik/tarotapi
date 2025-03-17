# step definitions for reading session feature
Given('i am a registered user') do
  @user = create(:user)
end

Given('i am logged in') do
  # implement authentication steps based on your auth system
  # this is a placeholder - adjust based on your actual auth implementation
  @current_user = @user
end

Given('there are spreads available') do
  @spread = create(:spread)
end

When('i choose a spread') do
  @selected_spread = @spread
end

When('i enter my question') do
  @question = 'what does my future hold?'
end

Then('a new reading session should be created') do
  @reading_session = create(:reading_session, 
    user: @current_user,
    spread: @selected_spread,
    question: @question
  )
  expect(@reading_session).to be_persisted
end

Then('i should see my cards') do
  @reading_session.spread.positions.each_with_index do |position, index|
    create(:card_reading, 
      reading_session: @reading_session, 
      position: index + 1,
      spread_position: position
    )
  end
  expect(@reading_session.card_readings.count).to eq(@reading_session.spread.positions.count)
end

Given('i have completed readings') do
  @completed_reading = create(:reading_session, :with_card_readings, 
    user: @current_user,
    status: 'completed'
  )
end

When('i visit my reading history') do
  @user_readings = @current_user.reading_sessions
end

Then('i should see my past readings') do
  expect(@user_readings).to include(@completed_reading)
end

Then('i should be able to view each reading\'s details') do
  reading = @user_readings.first
  expect(reading.card_readings).to be_present
  expect(reading.spread).to be_present
  expect(reading.question).to be_present
end

Given('the api is available') do
  @user = create(:user)
  @spread = create(:spread, user: @user)
  header 'accept', 'application/json'
  header 'content-type', 'application/json'
end

When('i request a new reading session with a spread') do
  # create some tarot cards for the reading
  @cards = create_list(:tarot_card, @spread.positions.length)
  
  post '/api/v1/reading_sessions', {
    spread_id: @spread.id,
    user_id: @user.id,
    question: 'what does my future hold?',
    card_ids: @cards.map(&:id),
    reversed_cards: []
  }.to_json
end

And('i provide a question') do
  @question = 'what does my future hold?'
end

Then('a new reading session should be created with a session id') do
  expect(json_response['data']['attributes']['session_id']).not_to be_nil
  @session_id = json_response['data']['attributes']['session_id']
end

And('i should receive the drawn cards') do
  expect(json_response['included']).to be_an(Array)
  card_readings = json_response['included'].select { |item| item['type'] == 'card_reading' }
  expect(card_readings.length).to eq(@spread.positions.length)
end

Given('there is an existing reading session') do
  @user = create(:user)
  @spread = create(:spread, user: @user)
  @reading_session = create(:reading_session, :with_card_readings, user: @user, spread: @spread)
  @session_id = @reading_session.session_id
  header 'accept', 'application/json'
  header 'content-type', 'application/json'
end

When('i request the reading session by id') do
  get "/api/v1/reading_sessions/#{@session_id}"
end

Then('i should receive the complete reading details') do
  expect(json_response['data']['attributes']['session_id']).to eq(@session_id)
  expect(json_response['included']).to be_an(Array)
  card_readings = json_response['included'].select { |item| item['type'] == 'card_reading' }
  expect(card_readings).to be_present
end

When('i request the available spreads') do
  # Create some public spreads
  create_list(:spread, 3, is_public: true)
  get '/api/v1/spreads'
end

Then('i should receive a list of spread options') do
  expect(json_response['data']).to be_an(Array)
  expect(json_response['data'].first['attributes']).to have_key('name')
end

And('each spread should include its positions') do
  expect(json_response['data'].first['attributes']['positions']).to be_an(Array)
end

When('i request a new reading session with an invalid spread id') do
  post '/api/v1/reading_sessions', {
    spread_id: 999999,
    user_id: @user.id,
    question: 'what does my future hold?'
  }.to_json
end

Then('i should receive a not found error') do
  expect(json_response['errors'].first['detail']).to include('not found')
end

When('i request a new reading session without a question') do
  post '/api/v1/reading_sessions', {
    spread_id: @spread.id,
    user_id: @user.id
  }.to_json
end

Then('i should receive a validation error') do
  expect(json_response['errors'].first['detail']).to include('blank')
end

When('i request a reading session with an invalid id') do
  get '/api/v1/reading_sessions/invalid-id'
end

Given('i have multiple reading sessions') do
  # Clear existing reading sessions to avoid uniqueness conflicts
  ReadingSession.delete_all
  
  @user = create(:user)
  
  # Create a pool of spreads to use
  @spreads = create_list(:spread, 3, user: @user)
  
  # Create past readings using the factory with card readings
  @past_readings = []
  3.times do |i|
    @past_readings << create(:reading_session, :with_card_readings,
      user: @user,
      spread: @spreads.sample,
      reading_date: 2.weeks.ago,
      question: "Past question #{i}: What does my future hold?"
    )
  end
  
  # Create recent readings using the factory with card readings
  @recent_readings = []
  2.times do |i|
    @recent_readings << create(:reading_session, :with_card_readings,
      user: @user,
      spread: @spreads.sample,
      reading_date: 2.days.ago,
      question: "Recent question #{i}: What does my career path look like?"
    )
  end
  
  header 'accept', 'application/json'
  header 'content-type', 'application/json'
end

When('i request readings between specific dates') do
  start_date = 1.week.ago.iso8601
  end_date = Time.current.iso8601
  
  get "/api/v1/reading_sessions?start_date=#{start_date}&end_date=#{end_date}&user_id=#{@user.id}"
end

Then('i should receive only readings within that range') do
  expect(json_response['data']).to be_an(Array)
  expect(json_response['data'].length).to eq(@recent_readings.length)
  
  json_response['data'].each do |reading|
    reading_date = Time.parse(reading['attributes']['reading_date'])
    expect(reading_date).to be > 1.week.ago
    expect(reading_date).to be <= Time.current
  end
end

When('i request reading session statistics') do
  get "/api/v1/reading_sessions/statistics?user_id=#{@user.id}"
end

Then('i should receive aggregated reading data') do
  expect(json_response['data']['attributes']).to have_key('total_readings')
  expect(json_response['data']['attributes']['total_readings']).to eq(@past_readings.length + @recent_readings.length)
end 