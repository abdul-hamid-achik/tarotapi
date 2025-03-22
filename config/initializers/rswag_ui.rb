# We're using redoc instead of rswag-ui
# This file is kept for reference only
=begin
Rswag::Ui.configure do |c|
  # List the Swagger endpoints that you want to be documented through the
  # swagger-ui. The first parameter is the path (absolute or relative to the UI
  # host) to the corresponding endpoint and the second is a title that will be
  # displayed in the document selector.
  # NOTE: If you're using rspec-api to expose Swagger files
  # (under openapi_root) as JSON or YAML endpoints, then the list below should
  # correspond to the relative paths for those endpoints.

  c.openapi_endpoint "/api/v1/spec.yaml", "tarot api v1 docs"

  # Add Basic Auth in case your API is private
  # c.basic_auth_enabled = true
  # c.basic_auth_credentials 'username', 'password'

  # determine default swagger url
  c.swagger_endpoint "/api/v1/spec.yaml", "tarot api v1 docs (swagger ui)"

  # define deeplink configuration
  # c.config_object = {
  #   deepLinking: true, # enable deep linking
  #   persistAuthorization: true # persist auth even after browser close
  # }
end
=end

Rswag::Ui.configure do |c|
  c.openapi_endpoint "/api/v1/spec.yaml", "Tarot API V1 Documentation"

  c.config_object = {
    deepLinking: true,
    displayOperationId: false,
    defaultModelsExpandDepth: 1,
    defaultModelExpandDepth: 1,
    defaultModelRendering: "model",
    displayRequestDuration: true,
    docExpansion: "list",
    filter: true,
    operationsSorter: "alpha",
    showExtensions: true,
    showCommonExtensions: true,
    tagsSorter: "alpha",
    persistAuthorization: true,
    tryItOutEnabled: true
  }
end
