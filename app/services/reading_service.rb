class ReadingService
  attr_reader :user, :spread, :cards, :positions, :reversed_cards, :reading, :birth_date, :name

  def initialize(user:, spread: nil, reading: nil, cards: [], positions: [], reversed_cards: [], birth_date: nil, name: nil)
    @user = user
    @spread = spread
    @reading = reading
    @cards = cards
    @positions = positions
    @reversed_cards = reversed_cards
    @birth_date = birth_date || reading&.birth_date
    @name = name || reading&.name
  end

  def create_reading
    ActiveRecord::Base.transaction do
      readings = []

      cards.each_with_index do |card_id, index|
        position_num = index + 1
        is_reversed = reversed_cards.include?(position_num)

        position_data = if spread.present?
          spread_positions = spread.positions
          position_info = spread_positions[index] || {}
          {
            name: position_info["name"],
            description: position_info["description"]
          }
        else
          { name: "Position #{position_num}", description: "Card position #{position_num}" }
        end

        reading = CardReading.create!(
          user: user,
          tarot_card_id: card_id,
          spread: spread,
          reading: reading,
          position: position_num,
          is_reversed: is_reversed,
          spread_position: position_data
        )

        readings << reading
      end

      # Generate interpretation if we have a spread or reading
      if (spread.present? || reading.present?) && readings.any?
        interpretation = generate_interpretation(readings)
      end

      readings
    end
  end

  def generate_interpretation_streaming(readings, &block)
    # Pass the reading context to the interpretation service
    service = InterpretationService.new(
      user: user,
      spread: spread,
      reading: reading,
      birth_date: birth_date,
      name: name
    )

    accumulated_interpretation = ""

    service.interpret_streaming(readings) do |chunk|
      accumulated_interpretation += chunk
      yield chunk if block_given?
    end

    # If we have a saved reading and interpretation was successful, save it
    if reading.present? && !accumulated_interpretation.empty?
      # Save interpretation to reading
      reading.update(interpretation: accumulated_interpretation)
    end

    accumulated_interpretation
  end

  def generate_interpretation(readings)
    # Pass the reading context to the interpretation service
    service = InterpretationService.new(
      user: user,
      spread: spread,
      reading: reading,
      birth_date: birth_date,
      name: name
    )

    interpretation = service.interpret(readings)

    # If we have a saved reading session and interpretation was successful, save it
    if (spread.present? || reading.present?) && readings.any?
      # Save interpretation to reading if it exists
      reading.update(interpretation: interpretation) if reading.present?
    end

    interpretation
  end

  def get_card_meaning(card_id, is_reversed = false)
    card = Card.find(card_id)

    llm_service = LlmService.instance

    # Get numerological information
    numerology = NumerologyService.get_card_numerology(card.name)

    # Get arcana information
    arcana_info = ArcanaService.get_card_info(card.name)

    # Get symbolism information
    symbolism = SymbolismService.get_card_symbolism(card.name)

    llm_service.get_card_meaning(
      card_name: card.name,
      is_reversed: is_reversed,
      numerology: numerology,
      arcana_info: arcana_info,
      symbolism: symbolism
    )
  end

  def analyze_card_combination(card_id1, card_id2)
    card1 = Card.find(card_id1)
    card2 = Card.find(card_id2)

    # Get combination analysis
    combination = SymbolismService.analyze_card_combination(card1.name, card2.name)

    # Get elemental combination
    elemental = SymbolismService.analyze_elemental_combination(card1.name, card2.name)

    {
      cards: [ card1.name, card2.name ],
      combination_type: combination[:type],
      combination_meaning: combination[:meaning],
      elemental_combination: elemental
    }
  end

  def get_numerological_insight
    return nil unless birth_date.present?

    llm_service = LlmService.instance

    # Calculate life path number
    life_path_number = NumerologyService.calculate_life_path_number(birth_date)

    # Calculate name number if name is provided
    name_number = name.present? ? NumerologyService.calculate_name_number(name) : nil

    # Get life path meaning
    life_path_meaning = NumerologyService.get_life_path_meaning(life_path_number)

    llm_service.get_numerological_insight(
      life_path_number: life_path_number,
      name_number: name_number,
      birth_date: birth_date,
      life_path_meaning: life_path_meaning
    )
  end

  def get_symbolism_analysis(card_ids)
    cards = card_ids.map { |id| Card.find(id) }

    llm_service = LlmService.instance

    # Get symbolism for each card
    symbols = {}
    cards.each do |card|
      card_symbolism = SymbolismService.identify_symbols_in_card(card.name)
      symbols[card.name] = card_symbolism
    end

    # Analyze spread pattern
    pattern = SymbolismService.analyze_spread_pattern(cards)

    llm_service.get_symbolism_analysis(
      cards: cards.map(&:name),
      symbols: symbols,
      pattern: pattern,
      is_reading: true
    )
  end

  def get_arcana_explanation(arcana_type, specific_card = nil)
    llm_service = LlmService.instance

    llm_service.get_arcana_explanation(
      arcana_type: arcana_type,
      specific_card: specific_card
    )
  end

  private

  def get_reading_context
    context = {}

    # Add spread name if available
    if spread.present?
      context[:spread_name] = spread.name
    elsif reading&.spread.present?
      context[:spread_name] = reading.spread.name
    else
      context[:spread_name] = "Custom Spread"
    end

    # Add question if available
    question = reading&.question
    context[:question] = question if question.present?

    # Add astrological context if available
    if params[:astrological_context].present?
      context[:astrological_context] = params[:astrological_context]
    elsif reading&.astrological_context.present?
      context[:astrological_context] = reading.astrological_context
    end

    # Add birth date if available for numerological insights
    context[:birth_date] = birth_date if birth_date.present?

    # Add name if available
    context[:name] = name if name.present?

    context
  end
end
