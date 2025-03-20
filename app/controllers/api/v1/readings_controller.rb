class Api::V1::ReadingsController < Api::V1::BaseController
  include ActionController::Live
  include AuthenticateRequest
  
  # Headers
  # - X-Stream-Response: true - Enable streaming response if subscribed (returns SSE stream)
  
  # Add check_reading_limit before action before creating a new reading and getting interpretations
  before_action :check_reading_limit, only: [:create, :create_with_spread, :interpret, :interpret_streaming, :numerology, :symbolism]
  before_action :set_reading, only: [:show, :update, :destroy]
  before_action :check_subscription_for_streaming, only: [:interpret_streaming]

  def index
    @readings = current_user.readings.order(created_at: :desc)

    render json: @readings
  end

  def show
    render json: @reading
  end

  def create
    @reading = current_user.readings.new(reading_params)

    if @reading.save
      # Increment reading count for the user
      current_user.increment_reading_count!
      
      render json: @reading, status: :created
    else
      render json: { errors: @reading.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def create_with_spread
    spread = Spread.find_by(id: params[:spread_id])
    unless spread
      return render json: { error: "spread not found" }, status: :not_found
    end

    @reading = Reading.new(
      user: current_user,
      spread: spread,
      question: params[:question]
    )

    if @reading.save
      # Draw cards for each position in the spread
      cards = Card.all.sample(spread.positions.count)
      
      spread.positions.each_with_index do |position, index|
        @reading.card_readings.create(
          user: current_user,
          card: cards[index],
          position: position["name"],
          is_reversed: [true, false].sample
        )
      end
      
      # Increment reading count for the user
      current_user.increment_reading_count!

      render json: @reading, status: :created
    else
      render json: { errors: @reading.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @reading.update(reading_params)
      render json: @reading
    else
      render json: { errors: @reading.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @reading.destroy
    head :no_content
  end

  def interpret_streaming
    reading = current_user.readings.find_by(session_id: params[:id])

    unless reading
      render json: {
        errors: [ {
          status: "404",
          title: "not found",
          detail: "reading not found"
        } ]
      }, status: :not_found
      return
    end

    # Update birth_date and name if provided
    reading.update(birth_date: params[:birth_date]) if params[:birth_date].present?
    reading.update(name: params[:name]) if params[:name].present?

    response.headers['Content-Type'] = 'text/event-stream'
    response.headers['Cache-Control'] = 'no-cache'
    response.headers['Connection'] = 'keep-alive'
    
    # Create an SSE object
    sse = ActionController::Live::SSE.new(response.stream, retry: 300, event: "interpretation")

    service = ReadingService.new(
      user: reading.user,
      spread: reading.spread,
      reading: reading,
      birth_date: reading.birth_date,
      name: reading.name
    )

    begin
      service.generate_interpretation_streaming(reading.card_readings) do |chunk|
        sse.write({ chunk: chunk })
      end
    rescue IOError
      # Client disconnected
    ensure
      # Count this as usage for subscription purposes if not already counted
      unless reading.usage_counted
        current_user.increment_reading_count!
        reading.update(usage_counted: true)
      end
      
      sse.close
    end
  end

  def interpret
    reading = current_user.readings.find_by(session_id: params[:id])

    unless reading
      render json: {
        errors: [ {
          status: "404",
          title: "not found",
          detail: "reading not found"
        } ]
      }, status: :not_found
      return
    end

    # Update birth_date and name if provided
    reading.update(birth_date: params[:birth_date]) if params[:birth_date].present?
    reading.update(name: params[:name]) if params[:name].present?

    service = ReadingService.new(
      user: reading.user,
      spread: reading.spread,
      reading: reading,
      birth_date: reading.birth_date,
      name: reading.name
    )

    interpretation = service.generate_interpretation(reading.card_readings)
    reading.update(interpretation: interpretation)

    # Count this as usage for subscription purposes if not already counted
    unless reading.usage_counted
      current_user.increment_reading_count!
      reading.update(usage_counted: true)
    end

    render json: { interpretation: interpretation }
  end

  def numerology
    reading = current_user.readings.find_by(session_id: params[:id])

    unless reading
      render json: {
        errors: [ {
          status: "404",
          title: "not found",
          detail: "reading not found"
        } ]
      }, status: :not_found
      return
    end

    # Update birth_date and name if provided
    reading.update(birth_date: params[:birth_date]) if params[:birth_date].present?
    reading.update(name: params[:name]) if params[:name].present?

    unless reading.birth_date.present?
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
      user: reading.user,
      reading: reading,
      birth_date: reading.birth_date,
      name: reading.name
    )

    insight = service.get_numerological_insight

    # Count this as usage for subscription purposes if not already counted
    unless reading.usage_counted
      current_user.increment_reading_count!
      reading.update(usage_counted: true)
    end

    render json: { numerological_insight: insight }
  end

  def symbolism
    reading = current_user.readings.find_by(session_id: params[:id])

    unless reading
      render json: {
        errors: [ {
          status: "404",
          title: "not found",
          detail: "reading not found"
        } ]
      }, status: :not_found
      return
    end

    card_ids = reading.card_readings.pluck(:card_id)

    service = ReadingService.new(
      user: reading.user,
      reading: reading
    )

    analysis = service.get_symbolism_analysis(card_ids)

    # Count this as usage for subscription purposes if not already counted
    unless reading.usage_counted
      current_user.increment_reading_count!
      reading.update(usage_counted: true)
    end

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

    service = ReadingService.new(user: current_user)

    explanation = service.get_arcana_explanation(arcana_type, params[:specific_card])

    render json: { arcana_explanation: explanation }
  end

  private
  
  # Check if the user has reached their reading limit
  def check_reading_limit
    if current_user.reading_limit_exceeded?
      subscription_url = "#{request.base_url}/api/v1/subscriptions"
      render json: { 
        error: "reading limit exceeded for your subscription plan",
        message: "please upgrade your subscription to continue",
        subscription_url: subscription_url
      }, status: :payment_required
    end
  end

  def set_reading
    @reading = current_user.readings.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "reading not found" }, status: :not_found
  end

  def reading_params
    params.require(:reading).permit(:spread_id, :question, :notes)
  end

  # Check if the user has permission to use streaming features
  def check_subscription_for_streaming
    # Allow streaming for users with active subscriptions only
    unless current_user.subscriptions.find_by(status: 'active')
      render json: { 
        error: "streaming requires an active subscription", 
        message: "please upgrade to a paid plan to access streaming features"
      }, status: :payment_required
      return
    end
    
    # Check for streaming header
    unless request.headers['X-Stream-Response'] == 'true'
      render json: { 
        error: "streaming header missing", 
        message: "set X-Stream-Response: true header to use streaming"
      }, status: :bad_request
    end
  end
end 