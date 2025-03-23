class CardsController < ApplicationController
  include AuthenticateRequest

  # get /cards/:id
  # retrieves a specific card by id
  # @param [string] id the id of the card to retrieve
  # @return [json] the card data in json format
  def show
    @card = Card.find_cached(params[:id])
    render json: @card
  rescue ActiveRecord::RecordNotFound
    render json: { error: "card not found" }, status: :not_found
  end

  # Cache index results
  def index
    # Cache key includes any query params to ensure different result sets are cached separately
    cache_key = "cards/index/#{params_cache_key}"

    @cards = Rails.cache.fetch(cache_key, expires_in: 1.day) do
      if params[:arcana]
        Card.find_by_arcana_cached(params[:arcana])
      elsif params[:suit]
        Card.find_by_suit_cached(params[:suit])
      else
        Card.all.order(:arcana, :suit, :rank, :name)
      end
    end

    render json: @cards
  end

  private

  # Generate a consistent cache key from the request parameters
  def params_cache_key
    # Sort query parameters to ensure consistent cache keys
    sorted_params = request.query_parameters.sort.map { |k, v| "#{k}=#{v}" }
    Digest::SHA256.hexdigest(sorted_params.join("&"))
  end
end
