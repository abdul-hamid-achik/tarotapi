desc "Validate OpenAPI specification without requiring a database"
task :validate_api_spec do
  require "yaml"
  require "json"
  require "openapi_parser"

  puts "Validating OpenAPI specification (standalone)..."

  spec_file_yaml = File.join(Dir.pwd, "public/api/v1/spec.yaml")
  spec_file_json = File.join(Dir.pwd, "public/api/v1/spec.json")

  if File.exist?(spec_file_yaml)
    puts "Using YAML spec file: #{spec_file_yaml}"
    spec = YAML.load_file(spec_file_yaml)
  elsif File.exist?(spec_file_json)
    puts "Using JSON spec file: #{spec_file_json}"
    spec = JSON.parse(File.read(spec_file_json))
  else
    puts "Error: Could not find OpenAPI spec file (tried #{spec_file_yaml} and #{spec_file_json})"
    exit 1
  end

  begin
    # Parse the OpenAPI spec without additional configuration
    api = OpenAPIParser.parse(spec)

    validate_schema(spec)

    puts "OpenAPI specification is valid!"
    exit 0
  rescue OpenAPIParser::OpenAPIError => e
    puts "OpenAPI specification validation failed:"
    puts e.message
    exit 1
  rescue StandardError => e
    puts "Error validating OpenAPI spec: #{e.message}"
    puts e.backtrace[0..5]
    exit 1
  end
end

def validate_schema(spec)
  # Basic schema validation
  unless spec["openapi"]
    raise "Missing 'openapi' version field"
  end

  unless spec["info"] && spec["info"]["title"] && spec["info"]["version"]
    raise "Missing required 'info' fields (title, version)"
  end

  unless spec["paths"] && !spec["paths"].empty?
    raise "API specification must contain at least one path"
  end

  # Skip security scheme validation if not defined
  if spec["security"]
    validate_references(spec)
  else
    puts "No global security requirements defined - skipping validation"
  end

  puts "Schema validation passed"
end

def validate_references(spec)
  # Check security schemes
  if spec["security"]
    spec["security"].each do |security_item|
      security_item.keys.each do |scheme_name|
        unless spec["components"] &&
               spec["components"]["securitySchemes"] &&
               spec["components"]["securitySchemes"][scheme_name]
          puts "Warning: Referenced security scheme '#{scheme_name}' not defined in components"
        end
      end
    end
  end

  puts "References validation passed"
end
