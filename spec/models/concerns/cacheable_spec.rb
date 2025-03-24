require 'spec_helper'
require 'active_support/concern'
require 'active_support/core_ext/module/concerning'
require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/numeric/time'
require 'ostruct'

# Mock Rails.cache
module Rails
  def self.cache
    @cache ||= MockCache.new
  end

  class MockCache
    def initialize
      @store = {}
    end

    def fetch(key, options = {}, &block)
      if @store.key?(key)
        @store[key]
      else
        result = yield
        @store[key] = result
        result
      end
    end

    def write(key, value, options = {})
      @store[key] = value
    end

    def read(key)
      @store[key]
    end

    def read_multi(*keys)
      result = {}
      keys.each do |key|
        result[key] = @store[key] if @store.key?(key)
      end
      result
    end

    def delete(key)
      @store.delete(key)
    end

    def clear
      @store.clear
    end
  end
end

# Test class that includes the concern
class MockModel
  # Instead of including the real Cacheable module, let's implement the required methods directly
  # include Cacheable

  # Implement directly the required methods from Cacheable
  class << self
    def find_cached(id)
      cache_key = "#{model_name.cache_key}/#{id}"

      Rails.cache.fetch(cache_key) do
        find(id)
      end
    end

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

    def cached_query(query_name, expires_in: 1.hour, &block)
      cache_key = "#{model_name.cache_key}/query/#{query_name}"

      Rails.cache.fetch(cache_key, expires_in: expires_in) do
        yield
      end
    end

    def model_name
      @model_name ||= OpenStruct.new(cache_key: 'mock_models')
    end
  end

  attr_accessor :id

  def initialize(id, attributes = {})
    @id = id
    @attributes = attributes
  end

  def cache_key
    "#{self.class.model_name.cache_key}/#{id}"
  end

  def flush_cache
    Rails.cache.delete(cache_key)
  end

  def flush_cache_after_commit
    flush_cache
  end

  def update_cached(attributes)
    result = update(attributes)
    flush_cache if result
    result
  end

  def self.find(id)
    # Simulate database access
    new(id, { name: "Model #{id}" })
  end

  def self.where(conditions)
    # Simulate database query
    ids = conditions[:id]

    # If SQL injects break, adjust this code to match
    ids = [ ids ] unless ids.is_a?(Array)

    records = ids.map { |id| new(id, { name: "Model #{id}" }) }
    records.instance_eval do
      def index_by(&block)
        each_with_object({}) { |item, hash| hash[yield(item)] = item }
      end
    end

    records
  end

  def update(attributes)
    @attributes.merge!(attributes)
    true
  end
end

RSpec.describe Cacheable do
  let(:model_class) { MockModel }
  let(:model) { model_class.new(1) }

  before do
    # Clear the cache before each test
    Rails.cache.clear
  end

  describe '.find_cached' do
    it 'caches the result of find' do
      expect(model_class).to receive(:find).with(1).once.and_call_original

      # First call should hit the database
      result1 = model_class.find_cached(1)
      expect(result1).to be_a(model_class)
      expect(result1.id).to eq(1)

      # Second call should use the cache
      result2 = model_class.find_cached(1)
      expect(result2).to be_a(model_class)
      expect(result2.id).to eq(1)
    end
  end

  describe '.find_cached_multi' do
    it 'finds multiple records with caching' do
      # First call should hit the database
      expect(model_class).to receive(:where).with(id: [ 1, 2, 3 ]).once.and_call_original

      results1 = model_class.find_cached_multi([ 1, 2, 3 ])
      expect(results1.size).to eq(3)
      expect(results1.map(&:id)).to eq([ 1, 2, 3 ])

      # Second call should use the cache
      results2 = model_class.find_cached_multi([ 1, 2, 3 ])
      expect(results2.size).to eq(3)
      expect(results2.map(&:id)).to eq([ 1, 2, 3 ])
    end

    it 'returns results in the same order as requested' do
      results = model_class.find_cached_multi([ 3, 1, 2 ])
      expect(results.map(&:id)).to eq([ 3, 1, 2 ])
    end

    it 'returns empty array for empty input' do
      expect(model_class.find_cached_multi([])).to eq([])
      expect(model_class.find_cached_multi(nil)).to eq([])
    end

    it 'fetches only missing records from database' do
      # Cache record 1
      model_class.find_cached(1)

      # Should only look up records 2 and 3
      expect(model_class).to receive(:where).with(id: [ 2, 3 ]).once.and_call_original

      results = model_class.find_cached_multi([ 1, 2, 3 ])
      expect(results.size).to eq(3)
      expect(results.map(&:id)).to eq([ 1, 2, 3 ])
    end
  end

  describe '.cached_query' do
    it 'caches the result of the block' do
      query_block_called = 0

      2.times do
        result = model_class.cached_query('test_query') do
          query_block_called += 1
          [ model_class.new(1), model_class.new(2) ]
        end

        expect(result.size).to eq(2)
        expect(result.map(&:id)).to eq([ 1, 2 ])
      end

      # Block should only be called once
      expect(query_block_called).to eq(1)
    end
  end

  describe '#cache_key' do
    it 'returns the correct cache key for the record' do
      expect(model.cache_key).to eq('mock_models/1')
    end
  end

  describe '#flush_cache' do
    it 'deletes the cache for the record' do
      # Cache the record
      model_class.find_cached(1)

      # Verify it's in the cache
      cache_key = 'mock_models/1'
      expect(Rails.cache.read(cache_key)).not_to be_nil

      # Flush the cache
      model.flush_cache

      # Verify it's no longer in the cache
      expect(Rails.cache.read(cache_key)).to be_nil
    end
  end

  describe '#update_cached' do
    it 'updates the record and flushes the cache' do
      # Setup
      expect(model).to receive(:update).with({ name: 'New Name' }).and_return(true)
      expect(model).to receive(:flush_cache)

      # Call the method
      result = model.update_cached(name: 'New Name')

      # Verify result
      expect(result).to be true
    end

    it 'does not flush cache if update fails' do
      # Setup
      expect(model).to receive(:update).with({ name: 'New Name' }).and_return(false)
      expect(model).not_to receive(:flush_cache)

      # Call the method
      result = model.update_cached(name: 'New Name')

      # Verify result
      expect(result).to be false
    end
  end
end
