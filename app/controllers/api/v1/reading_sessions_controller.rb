class Api::V1::ReadingSessionsController < Api::V1::BaseController
  def create
    user = User.find(params[:user_id])

    # If spread_id is provided, use that spread
    # Otherwise, create a dynamic spread based on current astrological conditions
    spread = if params[:spread_id].present?
      Spread.where(id: params[:spread_id]).first
    else
      # Get recommended spread based on current date
      spread_data = AstrologyService.recommended_spread

      # Create a temporary spread object (not saved to database)
      Spread.new(
        name: spread_data[:name],
        description: spread_data[:description],
        positions: spread_data[:positions],
        user: user,
        is_public: false,
        astrological_context: spread_data[:astrological_context]
      )
    end

    unless spread&.persisted?
      render json: {
        errors: [ {
          status: "404",
          title: "not found",
          detail: "spread not found"
        } ]
      }, status: :not_found
      return
    end

    reading_session = ReadingSession.new(reading_session_params.merge(
      user: user,
      spread: spread,
      astrological_context: spread.astrological_context
    ))

    if reading_session.save
      # Create card readings if card_ids are provided
      if params[:card_ids].present?
        service = ReadingService.new(
          user: user,
          spread: spread,
          reading_session: reading_session,
          cards: params[:card_ids],
          reversed_cards: params[:reversed_cards] || [],
          birth_date: reading_session.birth_date,
          name: reading_session.name
        )

        readings = service.create_reading
      end

      render json: ReadingSessionSerializer.new(reading_session, {
        include: [ :card_readings, :spread, :user ]
      }).serializable_hash, status: :created
    else
      render json: {
        errors: reading_session.errors.map { |error|
          {
            status: "422",
            title: "validation error",
            detail: error.full_message
          }
        }
      }, status: :unprocessable_entity
    end
  end

  def index
    user = User.find(params[:user_id])
    reading_sessions = user.reading_sessions.includes(:card_readings, :spread)

    if params[:start_date].present? && params[:end_date].present?
      start_date = Time.parse(params[:start_date])
      end_date = Time.parse(params[:end_date])
      reading_sessions = reading_sessions.where(reading_date: start_date..end_date)
    end

    reading_sessions = reading_sessions.order(created_at: :desc)

    render json: ReadingSessionSerializer.new(reading_sessions, {
      include: [ :card_readings, :spread ]
    }).serializable_hash
  end

  def show
    reading_session = ReadingSession.find_by(session_id: params[:id])

    if reading_session
      render json: ReadingSessionSerializer.new(reading_session, {
        include: [ :card_readings, :spread, :user ]
      }).serializable_hash
    else
      render json: {
        errors: [ {
          status: "404",
          title: "not found",
          detail: "reading session not found"
        } ]
      }, status: :not_found
    end
  end

  def interpret
    reading_session = ReadingSession.find_by(session_id: params[:id])

    unless reading_session
      render json: {
        errors: [ {
          status: "404",
          title: "not found",
          detail: "reading session not found"
        } ]
      }, status: :not_found
      return
    end

    # Update birth_date and name if provided
    reading_session.update(birth_date: params[:birth_date]) if params[:birth_date].present?
    reading_session.update(name: params[:name]) if params[:name].present?

    service = ReadingService.new(
      user: reading_session.user,
      spread: reading_session.spread,
      reading_session: reading_session,
      birth_date: reading_session.birth_date,
      name: reading_session.name
    )

    interpretation = service.generate_interpretation(reading_session.card_readings)
    reading_session.update(interpretation: interpretation)

    render json: { interpretation: interpretation }
  end

  def numerology
    reading_session = ReadingSession.find_by(session_id: params[:id])

    unless reading_session
      render json: {
        errors: [ {
          status: "404",
          title: "not found",
          detail: "reading session not found"
        } ]
      }, status: :not_found
      return
    end

    # Update birth_date and name if provided
    reading_session.update(birth_date: params[:birth_date]) if params[:birth_date].present?
    reading_session.update(name: params[:name]) if params[:name].present?

    unless reading_session.birth_date.present?
      render json: {
        errors: [ {
          status: "422",
          title: "validation error",
          detail: "birth date is required for numerological insights"
        } ]
      }, status: :unprocessable_entity
      return
    end

    service = ReadingService.new(
      user: reading_session.user,
      reading_session: reading_session,
      birth_date: reading_session.birth_date,
      name: reading_session.name
    )

    insight = service.get_numerological_insight

    render json: { numerological_insight: insight }
  end

  def symbolism
    reading_session = ReadingSession.find_by(session_id: params[:id])

    unless reading_session
      render json: {
        errors: [ {
          status: "404",
          title: "not found",
          detail: "reading session not found"
        } ]
      }, status: :not_found
      return
    end

    card_ids = reading_session.card_readings.pluck(:tarot_card_id)

    service = ReadingService.new(
      user: reading_session.user,
      reading_session: reading_session
    )

    analysis = service.get_symbolism_analysis(card_ids)

    render json: { symbolism_analysis: analysis }
  end

  def arcana_explanation
    arcana_type = params[:arcana_type]

    unless [ "major", "minor" ].include?(arcana_type)
      render json: {
        errors: [ {
          status: "422",
          title: "validation error",
          detail: "invalid arcana type. must be 'major' or 'minor'"
        } ]
      }, status: :unprocessable_entity
      return
    end

    service = ReadingService.new(user: User.find(params[:user_id]))

    explanation = service.get_arcana_explanation(arcana_type, params[:specific_card])

    render json: { arcana_explanation: explanation }
  end

  private

  def reading_session_params
    params.permit(:question, :birth_date, :name)
  end
end
