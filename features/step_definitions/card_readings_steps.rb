require 'json'

# Setup Steps

Given("there is an existing card with id {int}") do |id|
  # Check if card exists first, create if not
  unless Card.exists?(id)
    Card.create!(
      id: id,
      name: "Test Card #{id}",
      suit: "major",
      number: id,
      keywords: "test, example",
      meaning_upright: "Test upright meaning",
      meaning_reversed: "Test reversed meaning"
    )
  end
end

Given("there is an existing spread with id {int}") do |id|
  # Check if spread exists first, create if not
  unless Spread.exists?(id)
    Spread.create!(
      id: id,
      name: "Test Spread #{id}",
      description: "Test spread description",
      card_count: 3,
      positions: [ "Past", "Present", "Future" ]
    )
  end
end

Given("i have existing card readings") do
  # Create a card and a spread
  step 'there is an existing card with id 1'
  step 'there is an existing spread with id 1'

  # Create a reading for the user
  reading = Reading.create!(
    user: @user,
    spread_id: 1,
    question: "Test question",
    reading_date: Time.current
  )

  # Create a card reading
  @card_reading = CardReading.create!(
    user: @user,
    reading: reading,
    card_id: 1,
    spread_id: 1,
    position: 1,
    is_reversed: false,
    notes: "Test notes",
    reading_date: Time.current
  )
end

Given("i have an existing card reading") do
  step 'i have existing card readings'
end

Given("i have multiple card readings for a spread") do
  # Create cards
  (1..3).each do |i|
    step "there is an existing card with id #{i}"
  end

  # Create a spread
  step 'there is an existing spread with id 1'

  # Create a reading for the user
  reading = Reading.create!(
    user: @user,
    spread_id: 1,
    question: "Test question for multiple cards",
    reading_date: Time.current
  )

  # Create card readings for all positions
  @card_readings = []
  (1..3).each do |i|
    card_reading = CardReading.create!(
      user: @user,
      reading: reading,
      card_id: i,
      spread_id: 1,
      position: i,
      is_reversed: i.odd?,
      notes: "Position #{i} notes",
      reading_date: Time.current
    )
    @card_readings << card_reading
  end

  @reading_ids = @card_readings.map(&:id)
end

Given("there are cards with ids {int} and {int}") do |id1, id2|
  step "there is an existing card with id #{id1}"
  step "there is an existing card with id #{id2}"
end

Given("there is a card with id {int}") do |id|
  step "there is an existing card with id #{id}"
end

# Action Steps

When("i create a new card reading") do |table|
  data = table.hashes.first
  @request_payload = data

  @response = post "/api/v1/card_readings", params: @request_payload.to_json, headers: {
    'Content-Type': 'application/json',
    'Authorization': "Bearer #{@token}" # Use token if authenticated
  }
  @response_body = JSON.parse(@response.body) rescue {}
end

When("i create a new card reading with invalid data") do |table|
  data = table.hashes.first
  @request_payload = data

  @response = post "/api/v1/card_readings", params: @request_payload.to_json, headers: {
    'Content-Type': 'application/json',
    'Authorization': "Bearer #{@token}" # Use token if authenticated
  }
  @response_body = JSON.parse(@response.body) rescue {}
end

When("i request my card readings") do
  @response = get "/api/v1/card_readings", headers: {
    'Content-Type': 'application/json',
    'Authorization': "Bearer #{@token}"
  }
  @response_body = JSON.parse(@response.body) rescue {}
end

When("i request the card reading details") do
  @response = get "/api/v1/card_readings/#{@card_reading.id}", headers: {
    'Content-Type': 'application/json',
    'Authorization': "Bearer #{@token}"
  }
  @response_body = JSON.parse(@response.body) rescue {}
end

When("i request an interpretation for those readings") do
  @request_payload = { reading_ids: @reading_ids }

  @response = post "/api/v1/card_readings/interpret", params: @request_payload.to_json, headers: {
    'Content-Type': 'application/json',
    'Authorization': "Bearer #{@token}"
  }
  @response_body = JSON.parse(@response.body) rescue {}
end

When("i request an interpretation for non-existent readings") do
  @request_payload = { reading_ids: [ 999, 1000, 1001 ] }

  @response = post "/api/v1/card_readings/interpret", params: @request_payload.to_json, headers: {
    'Content-Type': 'application/json',
    'Authorization': "Bearer #{@token}"
  }
  @response_body = JSON.parse(@response.body) rescue {}
end

When("i request an analysis for card combination {int} and {int}") do |id1, id2|
  @request_payload = { card_id1: id1, card_id2: id2 }

  @response = post "/api/v1/card_readings/analyze_combination", params: @request_payload.to_json, headers: {
    'Content-Type': 'application/json',
    'Authorization': "Bearer #{@token}"
  }
  @response_body = JSON.parse(@response.body) rescue {}
end

# Assertion Steps

Then("the response should contain card reading details") do
  expect(@response_body).to have_key("id")
  expect(@response_body).to have_key("card_id")
  expect(@response_body).to have_key("position")
  expect(@response_body).to have_key("is_reversed")
end

Then("the response should contain a list of card readings") do
  expect(@response_body).to be_an(Array)

  unless @response_body.empty?
    expect(@response_body.first).to have_key("id")
    expect(@response_body.first).to have_key("card_id")
  end
end

Then("the response should contain detailed card reading information") do
  expect(@response_body).to have_key("id")
  expect(@response_body).to have_key("card_id")
  expect(@response_body).to have_key("position")
  expect(@response_body).to have_key("is_reversed")
  expect(@response_body).to have_key("notes")
  expect(@response_body).to have_key("reading_date")
end

Then("the response should contain an interpretation") do
  expect(@response_body).to have_key("interpretation")
  expect(@response_body["interpretation"]).to be_a(String)
  expect(@response_body["interpretation"].length).to be > 0
end

Then("the response should indicate no readings found") do
  expect(@response_body).to have_key("error")
  expect(@response_body["error"]).to eq("No readings found")
end

Then("the response should contain a combination analysis") do
  expect(@response_body).to have_key("combination_analysis")
  expect(@response_body["combination_analysis"]).to be_a(String)
  expect(@response_body["combination_analysis"].length).to be > 0
end

Then("the response should indicate cards not found") do
  expect(@response_body).to have_key("error")
  expect(@response_body["error"]).to eq("One or both cards not found")
end
