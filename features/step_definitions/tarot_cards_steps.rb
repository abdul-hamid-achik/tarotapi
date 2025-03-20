Given('there is an existing tarot card') do
  @card = create(:tarot_card)
end

When('i request all tarot cards') do
  get '/api/v1/tarot_cards'
end

Then('i should receive a list of cards') do
  expect(json_response['data']).to be_an(Array)
  expect(json_response['data']).not_to be_empty
end

And('each card should have basic attributes') do
  card = json_response['data'].first
  expect(card['attributes']).to include(
    'name',
    'suit',
    'number',
    'arcana_type',
    'keywords',
    'meaning_up',
    'meaning_reversed'
  )
end

When('i request the card details') do
  get "/api/v1/tarot_cards/#{@card.id}"
end

Then('i should receive complete card information') do
  expect(json_response['data']['attributes']).to include(
    'name',
    'suit',
    'number',
    'arcana_type',
    'keywords',
    'meaning_up',
    'meaning_reversed',
    'description',
    'element',
    'zodiac_sign'
  )
end

Given('there are cards of different suits') do
  @suits = ['wands', 'cups', 'swords', 'pentacles']
  @suits.each do |suit|
    create(:tarot_card, suit: suit)
  end
end

When('i filter cards by a specific suit') do
  @selected_suit = @suits.first
  get "/api/v1/tarot_cards?suit=#{@selected_suit}"
end

Then('i should only receive cards of that suit') do
  expect(json_response['data']).to be_an(Array)
  json_response['data'].each do |card|
    expect(card['attributes']['suit']).to eq(@selected_suit)
  end
end

Given('there are cards with different meanings') do
  create(:tarot_card, keywords: ['love', 'partnership'])
  create(:tarot_card, keywords: ['career', 'success'])
  create(:tarot_card, keywords: ['spiritual', 'growth'])
end

When('i search for cards with a specific keyword') do
  @search_keyword = 'love'
  get "/api/v1/tarot_cards?keyword=#{@search_keyword}"
end

Then('i should receive cards matching that keyword') do
  expect(json_response['data']).to be_an(Array)
  json_response['data'].each do |card|
    expect(card['attributes']['keywords']).to include(@search_keyword)
  end
end

Given('there is a card with reversed meaning') do
  @card = create(:tarot_card, 
    meaning_up: 'positive interpretation',
    meaning_reversed: 'challenging interpretation'
  )
end

When('i request the card\'s reversed interpretation') do
  get "/api/v1/tarot_cards/#{@card.id}?orientation=reversed"
end

Then('i should receive the reversed meaning') do
  expect(json_response['data']['attributes']['current_meaning'])
    .to eq(@card.meaning_reversed)
end

Given('there are cards of different categories') do
  @categories = ['major_arcana', 'minor_arcana']
  @categories.each do |category|
    create(:tarot_card, arcana_type: category)
  end
end

When('i filter cards by category') do
  @selected_category = @categories.first
  get "/api/v1/tarot_cards?category=#{@selected_category}"
end

Then('i should only receive cards of that category') do
  expect(json_response['data']).to be_an(Array)
  json_response['data'].each do |card|
    expect(card['attributes']['arcana_type']).to eq(@selected_category)
  end
end 