namespace :coverage do
  desc "create missing service spec files"
  task :generate_service_specs => :environment do
    service_files = Dir.glob("app/services/**/*.rb").map { |f| [f, File.basename(f, ".rb")] }
    spec_files = Dir.glob("spec/services/**/*_spec.rb").map { |f| File.basename(f, "_spec.rb") }
    
    missing = service_files.reject { |_, basename| spec_files.include?(basename) }
    
    if missing.empty?
      puts "all services already have specs"
    else
      puts "generating spec templates for #{missing.size} services:"
      
      missing.each do |file_path, service_name|
        # get the class name from the file
        file_content = File.read(file_path)
        class_name = service_name.split('_').map(&:capitalize).join
        
        # create directory if it doesn't exist
        spec_dir = File.dirname(file_path).gsub('app/', 'spec/')
        FileUtils.mkdir_p(spec_dir) unless Dir.exist?(spec_dir)
        
        # create spec file
        spec_path = "#{spec_dir}/#{service_name}_spec.rb"
        
        template = <<~SPEC
          require 'rails_helper'

          RSpec.describe #{class_name} do
            # implement tests for #{class_name} here
            
            describe "#initialize" do
              it "initializes successfully" do
                # add initialization test
              end
            end
            
            # add tests for the service's public methods
            
          end
        SPEC
        
        File.write(spec_path, template)
        puts "  - created #{spec_path}"
      end
    end
  end
  
  desc "analyze bdd coverage"
  task :analyze_bdd_coverage => :environment do
    # analyze controllers vs cucumber features
    controllers = Dir.glob("app/controllers/**/*.rb").map do |f| 
      controller_name = File.basename(f, ".rb").gsub("_controller", "")
      [f, controller_name]
    end
    
    features = Dir.glob("features/*.feature").map do |f| 
      feature_name = File.basename(f, ".feature")
      content = File.read(f)
      [f, feature_name, content]
    end
    
    puts "bdd coverage analysis:"
    puts "----------------------"
    
    controllers.each do |controller_file, controller_name|
      # check for direct feature name match
      matching_features = features.select do |_, feature_name, content|
        feature_name.include?(controller_name) || 
        controller_name.include?(feature_name.gsub('_', '')) ||
        content.include?(controller_name)
      end
      
      if matching_features.empty?
        puts "⚠️ no cucumber feature found for #{controller_name} controller"
        
        # suggest feature template
        class_name = controller_name.split('_').map(&:capitalize).join(' ')
        feature_name = "#{controller_name}.feature"
        
        template = <<~FEATURE
          Feature: #{class_name} api
            as an api client
            i want to interact with #{controller_name} resources
            so that i can [describe purpose]

          Scenario: list all #{controller_name.pluralize}
            Given the api is available
            When i request all #{controller_name.pluralize}
            Then i should receive a list of #{controller_name.pluralize}

          Scenario: get #{controller_name} details
            Given there is an existing #{controller_name}
            When i request the #{controller_name} details
            Then i should receive complete #{controller_name} information

          # add more scenarios as needed
        FEATURE
        
        puts "  suggestion: create features/#{feature_name}"
      else
        puts "✅ #{controller_name} controller covered by #{matching_features.map { |_, name, _| name }.join(', ')}"
      end
    end
  end
  
  desc "verify service method coverage"
  task :service_method_coverage => :environment do
    puts "analyzing service method coverage..."
    
    service_files = Dir.glob("app/services/**/*.rb")
    
    service_files.each do |service_file|
      service_name = File.basename(service_file, ".rb")
      spec_file = Dir.glob("spec/services/**/#{service_name}_spec.rb").first
      
      if spec_file
        # extract public methods from service
        service_content = File.read(service_file)
        public_methods = service_content.scan(/^\s*def\s+(\w+)/).flatten - ["initialize"]
        
        # extract tested methods from spec
        spec_content = File.read(spec_file)
        tested_methods = spec_content.scan(/describe\s+["']#(\w+)["']/).flatten
        
        untested_methods = public_methods - tested_methods
        
        if untested_methods.empty?
          puts "✅ #{service_name}: all public methods are covered by tests"
        else
          puts "⚠️ #{service_name}: missing tests for methods:"
          untested_methods.each { |method| puts "  - #{method}" }
        end
      end
    end
  end
  
  desc "run all test coverage tasks"
  task :all => [:generate_service_specs, :analyze_bdd_coverage, :service_method_coverage] do
    puts "completed coverage analysis"
  end
end 