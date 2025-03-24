# frozen_string_literal: true

# Configure Secure Headers
SecureHeaders::Configuration.default do |config|
  # For testing environment, we'll use a basic permissive configuration
  config.csp = SecureHeaders::OPT_OUT if Rails.env == "test"

  unless Rails.env == "test"
    config.csp = {
      default_src: %w['self'],
      script_src: %w['self' 'unsafe-inline'],
      style_src: %w['self' 'unsafe-inline'],
      img_src: %w['self' data:],
      connect_src: %w['self'],
      font_src: %w['self'],
      object_src: %w['none'],
      frame_src: %w['self'],
      media_src: %w['self'],
      frame_ancestors: %w['none'],
      form_action: %w['self'],
      base_uri: %w['self']
    }
  end

  # Enable XSS protection
  config.x_xss_protection = "1; mode=block"

  # Prevent MIME type sniffing
  config.x_content_type_options = "nosniff"

  # Clickjacking protection
  config.x_frame_options = "SAMEORIGIN"

  # HTTP Strict Transport Security
  config.hsts = "max-age=31536000; includeSubDomains"

  # Referrer policy
  config.referrer_policy = "same-origin"
end
