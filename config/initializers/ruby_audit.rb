# ensure ruby_audit is loaded properly
if Rails.env.development? || Rails.env.test?
  begin
    require "ruby_audit"
  rescue LoadError => e
    puts "Warning: ruby_audit gem could not be loaded: #{e.message}"
  end
end
