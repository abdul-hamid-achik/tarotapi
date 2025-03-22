require 'json'
require 'yaml'
require 'openapi_parser'

When('I request the OpenAPI specification') do
  @spec_path = Rails.root.join('public/api/v1/spec.yaml')
  expect(File.exist?(@spec_path)).to be true
  @spec = YAML.load_file(@spec_path)
end

Then('it should be a valid OpenAPI 3.0 document') do
  expect(@spec['openapi']).to start_with('3.0')
  expect(@spec['info']).to be_a(Hash)
  expect(@spec['paths']).to be_a(Hash)
end

Then('it should include security schemes') do
  expect(@spec['components']).to be_a(Hash)
  expect(@spec['components']['securitySchemes']).to be_a(Hash)
  expect(@spec['components']['securitySchemes']['bearerAuth']).to be_a(Hash)
  expect(@spec['components']['securitySchemes']['bearerAuth']['type']).to eq('http')
  expect(@spec['components']['securitySchemes']['bearerAuth']['scheme']).to eq('bearer')
end

Then('it should include authentication endpoints') do
  paths = @spec['paths']
  expect(paths['/api/v1/auth/register']).to be_a(Hash)
  expect(paths['/api/v1/auth/login']).to be_a(Hash)
  expect(paths['/api/v1/auth/refresh']).to be_a(Hash)
end

Then('it should document all implemented endpoints') do
  implemented_controllers = Dir[Rails.root.join('app/controllers/api/v1/**/*_controller.rb')]
  controller_endpoints = implemented_controllers.flat_map do |controller|
    File.readlines(controller).grep(/^\s*def\s+\w+/).map(&:strip)
  end

  documented_paths = @spec['paths'].keys
  controller_endpoints.each do |endpoint|
    method_name = endpoint.match(/def\s+(\w+)/)[1]
    expect(documented_paths.any? { |path| path.include?(method_name) }).to be true
  end
end

Then('each endpoint should have proper request\/response schemas') do
  @spec['paths'].each do |path, methods|
    methods.each do |method, details|
      next if %w[parameters summary tags description].include?(method)

      if details['requestBody']
        expect(details['requestBody']['content']).to be_a(Hash)
        expect(details['requestBody']['content']['application/json']['schema']).to be_a(Hash)
      end

      expect(details['responses']).to be_a(Hash)
      details['responses'].each do |code, response|
        expect(response['content']).to be_a(Hash) if response['content']
        expect(response['description']).to be_a(String)
      end
    end
  end
end

Then('it should document the {word} endpoint') do |endpoint_type|
  path = case endpoint_type
  when 'registration' then '/api/v1/auth/register'
  when 'login' then '/api/v1/auth/login'
  when 'token' then '/api/v1/auth/refresh'
  end

  expect(@spec['paths'][path]).to be_a(Hash)
end

Then('all authentication endpoints should have example responses') do
  auth_paths = @spec['paths'].select { |k, _| k.start_with?('/api/v1/auth/') }

  auth_paths.each do |_, methods|
    methods.each do |_, details|
      next unless details['responses']

      details['responses'].each do |_, response|
        next unless response['content']

        schema = response['content']['application/json']['schema']
        expect(schema['example'] || schema['examples']).to be_present
      end
    end
  end
end

Then('each endpoint should document error responses') do
  @spec['paths'].each do |_, methods|
    methods.each do |_, details|
      next unless details['responses']

      expect(details['responses'].keys).to include('400').or include('401').or include('422')
    end
  end
end

Then('error response schemas should be consistent') do
  error_schemas = @spec['paths'].values.flat_map do |methods|
    methods.values.flat_map do |details|
      next [] unless details['responses']
      details['responses'].select { |k, _| k.start_with?('4') }.values
    end
  end.compact

  error_schemas.each do |schema|
    next unless schema['content']
    error_content = schema['content']['application/json']['schema']
    expect(error_content['properties']).to have_key('errors').or have_key('error')
  end
end

Then('validation error responses should include example error messages') do
  validation_responses = @spec['paths'].values.flat_map do |methods|
    methods.values.flat_map do |details|
      next [] unless details['responses']
      details['responses'].select { |k, _| k == '422' }.values
    end
  end.compact

  validation_responses.each do |response|
    next unless response['content']
    schema = response['content']['application/json']['schema']
    expect(schema['example'] || schema['examples']).to be_present
  end
end

Then('it should include rate limiting headers in responses') do
  success_responses = @spec['paths'].values.flat_map do |methods|
    methods.values.flat_map do |details|
      next [] unless details['responses']
      details['responses'].select { |k, _| k.start_with?('2') }.values
    end
  end.compact

  success_responses.each do |response|
    expect(response['headers']).to be_present
    headers = response['headers']
    expect(headers).to include('X-RateLimit-Limit', 'X-RateLimit-Remaining', 'X-RateLimit-Reset')
  end
end

Then('it should document rate limit quotas') do
  expect(@spec['info']['description']).to include('rate limit')
end

Then('it should provide example rate limit responses') do
  rate_limit_responses = @spec['paths'].values.flat_map do |methods|
    methods.values.flat_map do |details|
      next [] unless details['responses']
      details['responses'].select { |k, _| k == '429' }.values
    end
  end.compact

  expect(rate_limit_responses).to be_present
  rate_limit_responses.each do |response|
    expect(response['content']['application/json']['schema']['example']).to be_present
  end
end
