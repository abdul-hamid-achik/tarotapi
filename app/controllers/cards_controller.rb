class CardsController < ApplicationController
  # get /cards/:id
  # retrieves a specific card by id
  # @param [string] id the id of the card to retrieve
  # @return [json] the card data in json format
  def show
    card = TarotCard.find(params[:id])
    render json: CardSerializer.new(card).serializable_hash
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'card not found' }, status: :not_found
  end
end 