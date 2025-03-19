class Api::V1::TarotCardsController < ApplicationController
  def index
    cards = TarotCard.all
    render json: TarotCardSerializer.new(cards).serializable_hash
  rescue StandardError => e
    render json: { error: e.message }, status: :internal_server_error
  end

  def show
    card = TarotCard.find(params[:id])
    render json: TarotCardSerializer.new(card).serializable_hash
  rescue ActiveRecord::RecordNotFound
    render json: { error: "card not found" }, status: :not_found
  rescue StandardError => e
    render json: { error: e.message }, status: :internal_server_error
  end
end
