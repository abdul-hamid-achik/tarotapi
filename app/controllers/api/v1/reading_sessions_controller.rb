module Api
  module V1
    class ReadingSessionsController < ApplicationController
      def index
        @reading_sessions = ReadingSession.all
        render json: { data: @reading_sessions }
      end

      def show
        @reading_session = ReadingSession.find_by(id: params[:id])

        if @reading_session
          render json: { data: @reading_session }
        else
          render json: { error: "reading session not found" }, status: :not_found
        end
      end

      def create
        @reading_session = ReadingSession.new(reading_session_params)

        if @reading_session.save
          render json: { data: @reading_session }, status: :created
        else
          render json: { errors: @reading_session.errors }, status: :unprocessable_entity
        end
      end

      private

      def reading_session_params
        params.require(:reading_session).permit(:user_id, :session_id, :reading_date, :status)
      end
    end
  end
end
