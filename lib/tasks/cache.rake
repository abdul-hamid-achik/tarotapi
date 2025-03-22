namespace :cache do
  desc "Warms up the cache with frequently accessed data"
  task warm: :environment do
    CacheService.warm_up_cache
  end

  desc "Clears all application caches"
  task clear: :environment do
    CacheService.clear_all_caches
  end

  desc "Clears and then warms up the cache"
  task reset: :environment do
    Rake::Task["cache:clear"].invoke
    Rake::Task["cache:warm"].invoke
  end

  namespace :models do
    desc "Clears cache for a specific model"
    task :clear, [:model_name] => :environment do |_, args|
      model_name = args[:model_name]
      abort "Please provide a model name" unless model_name
      
      begin
        model_class = model_name.classify.constantize
        CacheService.clear_model_cache(model_class)
      rescue NameError
        abort "Model '#{model_name}' not found"
      end
    end
  end
end 