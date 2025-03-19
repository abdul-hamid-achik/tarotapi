module ApiHelpers
  include Rack::Test::Methods

  def json_response
    JSON.parse(last_response.body)
  rescue JSON::ParserError
    nil
  end

  def set_json_headers
    header 'accept', 'application/json'
    header 'content-type', 'application/json'
  end

  def app
    Rails.application
  end
end

World(ApiHelpers)

Before do
  header 'Content-Type', 'application/json'
  header 'Accept', 'application/json'
end
