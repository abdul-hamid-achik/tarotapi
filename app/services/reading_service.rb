class ReadingService
  attr_reader :user, :spread, :cards, :positions, :reversed_cards, :reading_session, :birth_date, :name

  def initialize(user:, spread: nil, reading_session: nil, cards: [], positions: [], reversed_cards: [], birth_date: nil, name: nil)
    @user = user
    @spread = spread
    @reading_session = reading_session
    @cards = cards
    @positions = positions
    @reversed_cards = reversed_cards
    @birth_date = birth_date
    @name = name
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
          reading_session: reading_session,
          position: position_num,
          is_reversed: is_reversed,
          spread_position: position_data
        )

        readings << reading
      end

      # Generate interpretation if we have a spread or reading session
      if (spread.present? || reading_session.present?) && readings.any?
        interpretation = generate_interpretation(readings)

        # Update the reading session with the interpretation if it exists
        reading_session.update(interpretation: interpretation) if reading_session.present?
      end

      readings
    end
  end

  def generate_interpretation(readings)
    return if readings.empty?

    llm_service = LlmService.instance

    cards_data = readings.map do |reading|
      {
        card: reading.tarot_card,
        position: reading.position,
        is_reversed: reading.is_reversed,
        position_data: reading.spread_position
      }
    end

    # Get the spread name from either the spread or the reading session
    spread_name = if spread.present?
      spread.name
    elsif reading_session&.spread.present?
      reading_session.spread.name
    else
      "Custom"
    end

    # Get the question from the reading session if available
    question = reading_session&.question

    # Get astrological context from either the spread or the reading session
    astrological_context = if spread&.astrological_context.present?
      spread.astrological_context
    elsif reading_session&.astrological_context.present?
      reading_session.astrological_context
    else
      nil
    end

    # Get cards and positions in the format expected by LlmService
    cards = cards_data.map { |data| data[:card] }
    positions = cards_data.map { |data| data[:position_data] }
    reversed = cards_data.any? { |data| data[:is_reversed] }

    # Get numerological context if birth date is provided
    numerological_context = get_numerological_context if birth_date.present?

    # Get symbolism analysis for the cards
    symbolism_context = get_symbolism_context(cards)

    interpretation = llm_service.interpret_reading(
      cards: cards,
      positions: positions,
      spread_name: spread_name,
      is_reversed: reversed,
      question: question,
      astrological_context: astrological_context,
      numerological_context: numerological_context,
      symbolism_context: symbolism_context
    )

    # Update each reading with the interpretation
    readings.each do |reading|
      reading.update(interpretation: interpretation)
    end

    interpretation
  end

  def get_card_meaning(card_id, is_reversed = false)
    card = TarotCard.find(card_id)

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
    card1 = TarotCard.find(card_id1)
    card2 = TarotCard.find(card_id2)

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
    cards = card_ids.map { |id| TarotCard.find(id) }

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

  def get_numerological_context
    return nil unless birth_date.present?

    # Calculate life path number
    life_path_number = NumerologyService.calculate_life_path_number(birth_date)

    # Calculate name number if name is provided
    name_number = name.present? ? NumerologyService.calculate_name_number(name) : nil

    # Get life path meaning
    life_path_meaning = NumerologyService.get_life_path_meaning(life_path_number)

    {
      life_path_number: life_path_number,
      name_number: name_number,
      life_path_name: life_path_meaning[:name],
      life_path_description: life_path_meaning[:description],
      strengths: life_path_meaning[:strengths],
      challenges: life_path_meaning[:challenges]
    }
  end

  def get_symbolism_context(cards)
    return nil if cards.empty?

    # Get symbolism for each card
    card_symbolism = {}
    cards.each do |card|
      symbols = SymbolismService.identify_symbols_in_card(card.name)
      card_symbolism[card.name] = symbols
    end

    # Analyze card combinations if there are multiple cards
    combinations = []
    if cards.length > 1
      cards.each_with_index do |card1, i|
        cards[i+1..-1].each do |card2|
          combination = SymbolismService.analyze_card_combination(card1.name, card2.name)
          combinations << {
            cards: [ card1.name, card2.name ],
            type: combination[:type],
            meaning: combination[:meaning]
          } if combination

          # Add elemental combination if available
          elemental = SymbolismService.analyze_elemental_combination(card1.name, card2.name)
          combinations << {
            cards: [ card1.name, card2.name ],
            type: :elemental,
            meaning: elemental
          } if elemental
        end
      end
    end

    # Analyze spread pattern
    pattern = SymbolismService.analyze_spread_pattern(cards)

    {
      card_symbolism: card_symbolism,
      combinations: combinations,
      pattern: pattern
    }
  end
end
