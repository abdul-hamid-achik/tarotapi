desc "Validate OpenAPI specification without requiring a database"
task :validate_api_spec do
  require "yaml"
  require "json"
  require "openapi_parser"

  TaskLogger.info("Validating OpenAPI specification (standalone)...")

  spec_file_yaml = File.join(Dir.pwd, "public/api/v1/spec.yaml")
  spec_file_json = File.join(Dir.pwd, "public/api/v1/spec.json")

  if File.exist?(spec_file_yaml)
    TaskLogger.info("Using YAML spec file: #{spec_file_yaml}")
    spec = YAML.load_file(spec_file_yaml)
  elsif File.exist?(spec_file_json)
    TaskLogger.info("Using JSON spec file: #{spec_file_json}")
    spec = JSON.parse(File.read(spec_file_json))
  else
    TaskLogger.error("Could not find OpenAPI spec file (tried #{spec_file_yaml} and #{spec_file_json})")
    exit 1
  end

  begin
    # Parse the OpenAPI spec without additional configuration
    api = OpenAPIParser.parse(spec)

    validate_schema(spec)

    TaskLogger.info("OpenAPI specification is valid!")
    exit 0
  rescue OpenAPIParser::OpenAPIError => e
    TaskLogger.error("OpenAPI specification validation failed:")
    TaskLogger.error(e.message)
    exit 1
  rescue StandardError => e
    TaskLogger.error("Error validating OpenAPI spec: #{e.message}")
    TaskLogger.error(e.backtrace[0..5].join("\n"))
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
    TaskLogger.info("No global security requirements defined - skipping validation")
  end

  TaskLogger.info("Schema validation passed")
end

def validate_references(spec)
  # Check security schemes
  if spec["security"]
    spec["security"].each do |security_item|
      security_item.keys.each do |scheme_name|
        unless spec["components"] &&
               spec["components"]["securitySchemes"] &&
               spec["components"]["securitySchemes"][scheme_name]
          TaskLogger.warn("Referenced security scheme '#{scheme_name}' not defined in components")
        end
      end
    end
  end

  TaskLogger.info("References validation passed")
end
