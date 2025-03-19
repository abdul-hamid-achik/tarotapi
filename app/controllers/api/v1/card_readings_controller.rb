class Api::V1::CardReadingsController < ApplicationController
  def create
    user = UserResolutionService.new(user_params).resolve
    spread = params[:spread_id].present? ? Spread.where(id: params[:spread_id]).first : nil

    reading_session = ReadingSession.create!(
      user: user,
      spread: spread,
      question: params[:question],
      reading_date: Time.current
    )

    card_reading = CardReading.create!(
      user: user,
      reading_session: reading_session,
      tarot_card_id: params[:tarot_card_id],
      spread: spread,
      position: params[:position] || 1,
      is_reversed: params[:is_reversed] || false,
      notes: params[:notes],
      reading_date: Time.current
    )

    render json: card_reading
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("failed to create card reading: #{e.message}")
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
  rescue StandardError => e
    Rails.logger.error("unexpected error creating card reading: #{e.message}")
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def index
    user = UserResolutionService.new(user_params).resolve
    readings = user.card_readings.includes(:tarot_card, :spread, :reading_session).order(created_at: :desc)
    render json: readings
  rescue StandardError => e
    Rails.logger.error("error fetching card readings: #{e.message}")
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def show
    reading = CardReading.find(params[:id])
    render json: reading
  rescue ActiveRecord::RecordNotFound => e
    render json: { error: "card reading not found" }, status: :not_found
  rescue StandardError => e
    Rails.logger.error("error fetching card reading: #{e.message}")
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def interpret
    readings = CardReading.where(id: params[:reading_ids])

    if readings.empty?
      render json: { error: "No readings found" }, status: :not_found
      return
    end

    # All readings should belong to the same user and spread
    user = readings.first.user
    spread = readings.first.spread

    service = ReadingService.new(
      user: user,
      spread: spread
    )

    interpretation = service.generate_interpretation(readings)

    render json: { interpretation: interpretation }
  end

  def analyze_combination
    card_id1 = params[:card_id1]
    card_id2 = params[:card_id2]

    # Validate that both cards exist
    unless TarotCard.where(id: card_id1).exists? && TarotCard.where(id: card_id2).exists?
      render json: { error: "One or both cards not found" }, status: :not_found
      return
    end

    # Create a service to analyze the combination
    service = ReadingService.new(user: current_user || User.first)

    analysis = service.analyze_card_combination(card_id1, card_id2)

    render json: { combination_analysis: analysis }
  end

  private

  def user_params
    params.permit(:id, :external_id, :email, :provider)
  end
end
