class InterpretationService
  attr_reader :user, :spread, :reading, :birth_date, :name

  def initialize(user:, spread: nil, reading: nil, birth_date: nil, name: nil)
    @user = user
    @spread = spread
    @reading = reading
    @birth_date = birth_date
    @name = name
    
    # Initialize LlmService with user
    @llm_service = LlmService.instance
    @llm_service.set_user(user)
  end

  def interpret(readings)
    reading_context = prepare_context(readings)

    @llm_service.interpret_reading(
      cards: reading_context[:cards],
      positions: reading_context[:positions],
      spread_name: reading_context[:spread_name],
      is_reversed: reading_context[:is_reversed],
      question: reading_context[:question],
      astrological_context: reading_context[:astrological_context],
      numerological_context: reading_context[:numerological_context],
      symbolism_context: reading_context[:symbolism_context]
    )
  end

  def interpret_streaming(readings, &block)
    reading_context = prepare_context(readings)

    @llm_service.interpret_reading_streaming(
      cards: reading_context[:cards],
      positions: reading_context[:positions],
      spread_name: reading_context[:spread_name],
      is_reversed: reading_context[:is_reversed],
      question: reading_context[:question],
      astrological_context: reading_context[:astrological_context],
      numerological_context: reading_context[:numerological_context],
      symbolism_context: reading_context[:symbolism_context]
    ) do |chunk|
      yield chunk if block_given?
    end
  end

  private

  def prepare_context(readings)
    cards = []
    positions = []
    spread_name = spread&.name || reading&.spread&.name || "Custom Spread"
    is_reversed = []

    # Process card readings
    readings.each_with_index do |card_reading, index|
      card = card_reading.card
      position_index = index + 1
      position_name = card_reading.spread_position&.fetch("name", nil) || "Position #{position_index}"
      position_desc = card_reading.spread_position&.fetch("description", nil) || "Card position #{position_index}"

      cards << {
        name: card.name,
        arcana: card.arcana,
        rank: card.rank,
        suit: card.suit,
        description: card.description,
        symbols: card.symbols
      }

      positions << {
        name: position_name,
        description: position_desc,
        position: card_reading.position
      }

      is_reversed << card_reading.is_reversed if card_reading.is_reversed
    end

    # Get additional context
    question = reading&.question
    astrological_context = reading&.astrological_context

    # Get numerological context if birth date is provided
    numerological_context = nil
    if birth_date.present?
      numerological_context = {
        life_path_number: NumerologyService.calculate_life_path_number(birth_date),
        birth_date: birth_date.to_s
      }

      if name.present?
        numerological_context[:name_number] = NumerologyService.calculate_name_number(name)
        numerological_context[:name] = name
      end
    end

    # Get symbolism context from the cards
    symbolism_context = {
      cards: cards.map { |c| c[:name] },
      symbolism: {}
    }

    cards.each do |card|
      symbolism_context[:symbolism][card[:name]] = SymbolismService.identify_symbols_in_card(card[:name])
    end

    {
      cards: cards,
      positions: positions,
      spread_name: spread_name,
      is_reversed: is_reversed,
      question: question,
      astrological_context: astrological_context,
      numerological_context: numerological_context,
      symbolism_context: symbolism_context
    }
  end
end
