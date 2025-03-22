module Cacheable
  extend ActiveSupport::Concern

  included do
    after_commit :flush_cache
  end

  class_methods do
    # Find a record by ID with caching
    def find_cached(id)
      cache_key = "#{model_name.cache_key}/#{id}"
      
      Rails.cache.fetch(cache_key) do
        find(id)
      end
    end

    # Find multiple records by IDs with caching
    def find_cached_multi(ids)
      return [] if ids.blank?

      # Create cache keys for each id
      cache_keys = ids.map { |id| "#{model_name.cache_key}/#{id}" }
      
      # Try to get all from cache
      cached_records = Rails.cache.read_multi(*cache_keys)
      
      # Check which ones we need to fetch from the database
      missing_ids = []
      
      ids.each_with_index do |id, index|
        cache_key = cache_keys[index]
        missing_ids << id unless cached_records[cache_key]
      end
      
      # Fetch missing records from the database
      if missing_ids.any?
        missing_records = where(id: missing_ids).index_by(&:id)
        
        # Write each missing record to cache
        missing_records.each do |id, record|
          cache_key = "#{model_name.cache_key}/#{id}"
          Rails.cache.write(cache_key, record)
          cached_records[cache_key] = record
        end
      end
      
      # Return records in the same order as requested
      ids.map { |id| cached_records["#{model_name.cache_key}/#{id}"] }.compact
    end

    # Cache complex queries for a specified duration
    def cached_query(query_name, expires_in: 1.hour, &block)
      cache_key = "#{model_name.cache_key}/query/#{query_name}"
      
      Rails.cache.fetch(cache_key, expires_in: expires_in) do
        yield
      end
    end
  end

  # Instance methods
  
  # Get the cache key for this record
  def cache_key
    "#{self.class.model_name.cache_key}/#{id}"
  end
  
  # Flush all caches related to this record
  def flush_cache
    Rails.cache.delete(cache_key)
    # Implement additional cache clearing if needed for associations
  end
  
  # Update a specific field with cache refresh
  def update_cached(attributes)
    result = update(attributes)
    flush_cache if result
    result
  end
end 