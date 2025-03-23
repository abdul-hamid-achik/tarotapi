module Api
  module V1
    class TarotCardsController < Api::V1::BaseController
      def index
        @cards = Card.all
        render json: { data: @cards }
      end

      def show
        begin
          @card = Card.find(params[:id])
          render json: { data: @card }
        rescue ActiveRecord::RecordNotFound
          render json: { error: "card not found" }, status: :not_found
        end
      end
    end
  end
end 