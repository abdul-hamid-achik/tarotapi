class PromptService
  PROMPT_TYPES = {
    tarot_reading: "tarot_reading",
    card_meaning: "card_meaning",
    spread_explanation: "spread_explanation",
    astrological_influence: "astrological_influence",
    daily_guidance: "daily_guidance",
    spiritual_growth: "spiritual_growth",
    relationship_advice: "relationship_advice",
    career_guidance: "career_guidance",
    personal_development: "personal_development",
    numerological_insight: "numerological_insight",
    symbolism_analysis: "symbolism_analysis",
    arcana_explanation: "arcana_explanation"
  }

  class << self
    def get_prompt(type, context = {})
      case type
      when PROMPT_TYPES[:tarot_reading]
        tarot_reading_prompt(context)
      when PROMPT_TYPES[:card_meaning]
        card_meaning_prompt(context)
      when PROMPT_TYPES[:spread_explanation]
        spread_explanation_prompt(context)
      when PROMPT_TYPES[:astrological_influence]
        astrological_influence_prompt(context)
      when PROMPT_TYPES[:daily_guidance]
        daily_guidance_prompt(context)
      when PROMPT_TYPES[:spiritual_growth]
        spiritual_growth_prompt(context)
      when PROMPT_TYPES[:relationship_advice]
        relationship_advice_prompt(context)
      when PROMPT_TYPES[:career_guidance]
        career_guidance_prompt(context)
      when PROMPT_TYPES[:personal_development]
        personal_development_prompt(context)
      when PROMPT_TYPES[:numerological_insight]
        numerological_insight_prompt(context)
      when PROMPT_TYPES[:symbolism_analysis]
        symbolism_analysis_prompt(context)
      when PROMPT_TYPES[:arcana_explanation]
        arcana_explanation_prompt(context)
      else
        raise ArgumentError, "Unknown prompt type: #{type}"
      end
    end

    private

    def tarot_reading_prompt(context)
      {
        system: <<~PROMPT,
          you are a skilled tarot reader with deep knowledge of symbolism, archetypes, and the human psyche.
          you are also knowledgeable about astrology, zodiac signs, planetary influences, seasonal energies, numerology, and tarot symbolism.
          your task is to interpret tarot readings with empathy, insight, and wisdom.
          focus on providing constructive, empowering interpretations that help people understand their situation
          and potential paths forward. avoid doom and gloom predictions.

          format your responses in clear sections:
          - overall theme
          - position-by-position interpretation
          - card interactions and combinations
          - numerological influences
          - astrological influences (if provided)
          - symbolic patterns and insights
          - key insights and advice

          use markdown formatting for clarity.
        PROMPT
        user: build_tarot_reading_user_prompt(context)
      }
    end

    def card_meaning_prompt(context)
      {
        system: <<~PROMPT,
          you are a skilled tarot reader with deep knowledge of tarot symbolism and card meanings.
          your task is to explain the meaning of a specific tarot card in detail.
          provide both upright and reversed meanings, and explain the symbolism in the card.
          include numerological associations and elemental influences.

          format your response in clear sections:
          - card overview
          - upright meaning
          - reversed meaning
          - symbolism and imagery
          - numerological significance
          - elemental and astrological associations
          - advice when this card appears

          use markdown formatting for clarity.
        PROMPT
        user: <<~PROMPT
          explain the meaning of the #{context[:card_name]} tarot card.
          include both upright and reversed meanings, and explain the symbolism in the card.
          discuss the numerological significance and elemental associations.
          provide advice for when this card appears in a reading.
        PROMPT
      }
    end

    def spread_explanation_prompt(context)
      {
        system: <<~PROMPT,
          you are a skilled tarot reader with deep knowledge of tarot spreads and layouts.
          your task is to explain a specific tarot spread in detail.
          describe the purpose of the spread, the meaning of each position, and how to interpret the spread as a whole.
          include information about the symbolic pattern of the spread and its significance.

          format your response in clear sections:
          - spread overview
          - symbolic pattern significance
          - position-by-position explanation
          - tips for interpretation

          use markdown formatting for clarity.
        PROMPT
        user: <<~PROMPT
          explain the #{context[:spread_name]} tarot spread.
          describe the purpose of the spread, the meaning of each position, and how to interpret the spread as a whole.
          explain the significance of the spread's pattern or shape.
          provide tips for interpreting this spread.
        PROMPT
      }
    end

    def astrological_influence_prompt(context)
      {
        system: <<~PROMPT,
          you are a skilled astrologer with deep knowledge of zodiac signs, planetary influences, and astrological events.
          your task is to explain how current astrological conditions might influence a person's life.

          format your response in clear sections:
          - current astrological overview
          - zodiac sign influence
          - planetary influences
          - elemental energies
          - advice for navigating current energies

          use markdown formatting for clarity.
        PROMPT
        user: <<~PROMPT
          explain how the current astrological conditions might influence a person's life:

          Zodiac Sign: #{context[:zodiac_sign]}
          Element: #{context[:element]}
          Ruling Planet: #{context[:ruling_planet]}
          Season: #{context[:season]}
          Moon Phase: #{context[:moon_phase]}

          provide advice for navigating these energies.
        PROMPT
      }
    end

    def daily_guidance_prompt(context)
      {
        system: <<~PROMPT,
          you are a skilled tarot reader providing daily guidance.
          your task is to interpret a single card drawn for daily guidance.
          focus on providing practical, actionable advice for the day ahead.
          include numerological and symbolic insights relevant to the card.

          format your response in clear sections:
          - card overview
          - today's message
          - numerological influence
          - key symbols and their meaning
          - practical advice

          use markdown formatting for clarity.
        PROMPT
        user: <<~PROMPT
          interpret this card drawn for daily guidance: #{context[:card_name]}#{context[:is_reversed] ? " (Reversed)" : ""}

          include insights about the card's numerology (#{context[:numerology][:number]}) and key symbols.
          provide practical, actionable advice for the day ahead based on this card.
        PROMPT
      }
    end

    def spiritual_growth_prompt(context)
      {
        system: <<~PROMPT,
          you are a spiritual guide with deep knowledge of tarot and personal growth.
          your task is to interpret a tarot reading focused on spiritual growth and development.
          focus on providing insights that help the querent deepen their spiritual practice and understanding.
          incorporate numerological patterns and symbolic insights in your interpretation.

          format your response in clear sections:
          - spiritual overview
          - insights from each card
          - numerological patterns
          - symbolic guidance
          - practices for spiritual growth
          - meditation focus

          use markdown formatting for clarity.
        PROMPT
        user: build_spiritual_growth_user_prompt(context)
      }
    end

    def relationship_advice_prompt(context)
      {
        system: <<~PROMPT,
          you are a relationship counselor with deep knowledge of tarot.
          your task is to interpret a tarot reading focused on relationships.
          focus on providing insights that help the querent understand their relationship dynamics
          and improve their connections with others.
          include relevant symbolic and numerological insights.

          format your response in clear sections:
          - relationship overview
          - insights from each card
          - card combinations and interactions
          - symbolic patterns in the reading
          - advice for improving relationships
          - reflection questions

          use markdown formatting for clarity.
        PROMPT
        user: build_relationship_advice_user_prompt(context)
      }
    end

    def career_guidance_prompt(context)
      {
        system: <<~PROMPT,
          you are a career counselor with deep knowledge of tarot.
          your task is to interpret a tarot reading focused on career and professional life.
          focus on providing insights that help the querent understand their career path
          and make informed professional decisions.
          incorporate elemental and numerological influences in your guidance.

          format your response in clear sections:
          - career overview
          - insights from each card
          - elemental influences on career
          - numerological timing factors
          - professional advice
          - action steps

          use markdown formatting for clarity.
        PROMPT
        user: build_career_guidance_user_prompt(context)
      }
    end

    def personal_development_prompt(context)
      {
        system: <<~PROMPT,
          you are a personal development coach with deep knowledge of tarot.
          your task is to interpret a tarot reading focused on personal growth and self-improvement.
          focus on providing insights that help the querent understand their strengths, challenges,
          and opportunities for growth.
          include symbolic patterns and archetypes present in the reading.

          format your response in clear sections:
          - personal overview
          - insights from each card
          - archetypal patterns
          - symbolic guidance
          - growth opportunities
          - action steps

          use markdown formatting for clarity.
        PROMPT
        user: build_personal_development_user_prompt(context)
      }
    end

    def numerological_insight_prompt(context)
      {
        system: <<~PROMPT,
          you are a numerology expert with deep understanding of how numbers influence life paths and personal development.
          your task is to provide numerological insights based on the provided information.
          explain the significance of the numbers and how they might influence the person's life or situation.

          format your response in clear sections:
          - numerological overview
          - life path number interpretation
          - name number significance (if provided)
          - current cycle influences
          - practical guidance

          use markdown formatting for clarity.
        PROMPT
        user: <<~PROMPT
          provide numerological insights for:

          Life Path Number: #{context[:life_path_number]}
          Name Number: #{context[:name_number] || "Not provided"}
          Birth Date: #{context[:birth_date] || "Not provided"}

          explain how these numbers might influence the person's life path, personality, and current situation.
          provide practical guidance based on these numerological insights.
        PROMPT
      }
    end

    def symbolism_analysis_prompt(context)
      {
        system: <<~PROMPT,
          you are an expert in symbolic interpretation with deep knowledge of universal symbols, archetypes, and their meanings.
          your task is to analyze the symbols present in a tarot reading or specific card.
          explain the significance of these symbols and how they relate to the querent's situation.

          format your response in clear sections:
          - symbolic overview
          - key symbols and their meanings
          - archetypal patterns
          - symbolic advice and guidance

          use markdown formatting for clarity.
        PROMPT
        user: <<~PROMPT
          analyze the symbolism in #{context[:is_reading] ? "this tarot reading" : "the #{context[:card_name]} card"}:

          #{context[:symbols].map { |symbol, meaning| "- #{symbol}: #{meaning}" }.join("\n")}

          explain how these symbols relate to each other and what patterns they form.
          provide guidance based on this symbolic analysis.
        PROMPT
      }
    end

    def arcana_explanation_prompt(context)
      {
        system: <<~PROMPT,
          you are a tarot scholar with extensive knowledge of the major and minor arcana.
          your task is to explain the significance of a specific arcana group or card.
          provide detailed information about its history, symbolism, and interpretive tradition.

          format your response in clear sections:
          - arcana overview
          - historical context
          - symbolic significance
          - interpretive approaches
          - modern relevance

          use markdown formatting for clarity.
        PROMPT
        user: <<~PROMPT
          explain the significance of the #{context[:arcana_type]} arcana#{context[:specific_card] ? ", specifically the #{context[:specific_card]} card" : ""}.

          include information about:
          - its place in tarot tradition
          - key symbolic elements
          - relationship to other cards
          - interpretive approaches
          - relevance to modern readers
        PROMPT
      }
    end

    def build_tarot_reading_user_prompt(context)
      cards_info = context[:cards].map.with_index do |card, i|
        position = context[:positions][i]
        reversed = context[:is_reversed] ? " (Reversed)" : ""

        # Get additional information about the card
        numerology = NumerologyService.get_card_numerology(card.name)
        arcana_info = ArcanaService.get_card_info(card.name)

        card_info = "Position: #{position["name"]} - #{position["description"]}\n" \
                    "Card: #{card.name}#{reversed}\n" \
                    "Card Meaning: #{card.description}\n" \
                    "Symbols: #{card.symbols}\n"

        # Add numerological information if available
        if numerology[:number]
          card_info += "Numerology: #{numerology[:number]} - #{numerology[:meaning]}\n"
        end

        # Add elemental information if available
        if arcana_info[:element]
          card_info += "Element: #{arcana_info[:element]}\n"
        end

        card_info + "\n"
      end.join

      question_text = context[:question].present? ? "Question: #{context[:question]}\n\n" : ""

      astrology_text = ""
      if context[:astrological_context].present?
        astrology_text = <<~ASTRO
          Astrological Context:
          - Zodiac Sign: #{context[:astrological_context]["zodiac_sign"]}
          - Element: #{context[:astrological_context]["element"]}
          - Ruling Planet: #{context[:astrological_context]["ruling_planet"]}
          - Season: #{context[:astrological_context]["season"].capitalize}
          - Moon Phase: #{context[:astrological_context]["moon_phase"]}

        ASTRO
      end

      # Add information about card combinations if there are multiple cards
      combinations_text = ""
      if context[:cards].length > 1
        combinations = []

        # Analyze pairs of cards
        context[:cards].each_with_index do |card1, i|
          context[:cards][i+1..-1].each do |card2|
            combination = SymbolismService.analyze_card_combination(card1.name, card2.name)
            combinations << "#{card1.name} + #{card2.name}: #{combination[:meaning]}" if combination

            # Add elemental combination if available
            elemental = SymbolismService.analyze_elemental_combination(card1.name, card2.name)
            combinations << "Elements (#{card1.name} + #{card2.name}): #{elemental}" if elemental
          end
        end

        unless combinations.empty?
          combinations_text = "Card Combinations:\n#{combinations.join("\n")}\n\n"
        end
      end

      # Add information about the spread pattern
      pattern_text = ""
      if context[:positions].length > 0
        pattern = SymbolismService.analyze_spread_pattern(context[:positions])
        pattern_text = "Spread Pattern: #{pattern[:pattern].capitalize} - #{pattern[:meaning]}\n\n"
      end

      <<~PROMPT
        interpret this #{context[:spread_name]} tarot reading:

        #{question_text}#{astrology_text}#{pattern_text}#{combinations_text}#{cards_info}

        provide a thoughtful interpretation that connects the cards' meanings
        with their positions in the spread and how they relate to each other.
        include insights about numerological patterns, symbolic connections, and elemental influences.
        #{context[:question].present? ? "Focus on answering the querent's question." : ""}
        #{context[:astrological_context].present? ? "Include how the current astrological influences affect the reading." : ""}
      PROMPT
    end

    def build_spiritual_growth_user_prompt(context)
      cards_info = context[:cards].map.with_index do |card, i|
        # Get additional information about the card
        numerology = NumerologyService.get_card_numerology(card.name)
        arcana_info = ArcanaService.get_card_info(card.name)

        card_info = "Card #{i+1}: #{card.name}#{context[:is_reversed] ? " (Reversed)" : ""}\n" \
                    "Card Meaning: #{card.description}\n" \
                    "Symbols: #{card.symbols}\n"

        # Add numerological information if available
        if numerology[:number]
          card_info += "Numerology: #{numerology[:number]} - #{numerology[:meaning]}\n"
        end

        # Add elemental information if available
        if arcana_info[:element]
          card_info += "Element: #{arcana_info[:element]}\n"
        end

        card_info + "\n"
      end.join

      # Add information about the spread pattern
      pattern_text = ""
      if context[:cards].length > 0
        pattern = SymbolismService.analyze_spread_pattern(context[:cards])
        pattern_text = "Spread Pattern: #{pattern[:pattern].capitalize} - #{pattern[:meaning]}\n\n"
      end

      <<~PROMPT
        interpret this spiritual growth tarot reading:

        #{pattern_text}#{cards_info}

        provide insights that help deepen spiritual practice and understanding.
        include analysis of numerological patterns and symbolic connections between the cards.
        suggest specific practices or meditations based on the cards drawn.
      PROMPT
    end

    def build_relationship_advice_user_prompt(context)
      cards_info = context[:cards].map.with_index do |card, i|
        position = context[:positions][i]

        # Get additional information about the card
        numerology = NumerologyService.get_card_numerology(card.name)
        arcana_info = ArcanaService.get_card_info(card.name)

        card_info = "Position: #{position["name"]} - #{position["description"]}\n" \
                    "Card: #{card.name}#{context[:is_reversed] ? " (Reversed)" : ""}\n" \
                    "Card Meaning: #{card.description}\n"

        # Add numerological information if available
        if numerology[:number]
          card_info += "Numerology: #{numerology[:number]} - #{numerology[:meaning]}\n"
        end

        # Add elemental information if available
        if arcana_info[:element]
          card_info += "Element: #{arcana_info[:element]}\n"
        end

        card_info + "\n"
      end.join

      question_text = context[:question].present? ? "Question about relationship: #{context[:question]}\n\n" : ""

      # Add information about card combinations if there are multiple cards
      combinations_text = ""
      if context[:cards].length > 1
        combinations = []

        # Analyze pairs of cards
        context[:cards].each_with_index do |card1, i|
          context[:cards][i+1..-1].each do |card2|
            combination = SymbolismService.analyze_card_combination(card1.name, card2.name)
            combinations << "#{card1.name} + #{card2.name}: #{combination[:meaning]}" if combination
          end
        end

        unless combinations.empty?
          combinations_text = "Card Combinations:\n#{combinations.join("\n")}\n\n"
        end
      end

      <<~PROMPT
        interpret this relationship tarot reading:

        #{question_text}#{combinations_text}#{cards_info}

        provide insights that help understand relationship dynamics and improve connections.
        analyze how the cards interact with each other and what patterns they form.
        suggest specific reflection questions and actions to improve relationships.
      PROMPT
    end

    def build_career_guidance_user_prompt(context)
      cards_info = context[:cards].map.with_index do |card, i|
        position = context[:positions][i]

        # Get additional information about the card
        numerology = NumerologyService.get_card_numerology(card.name)
        arcana_info = ArcanaService.get_card_info(card.name)

        card_info = "Position: #{position["name"]} - #{position["description"]}\n" \
                    "Card: #{card.name}#{context[:is_reversed] ? " (Reversed)" : ""}\n" \
                    "Card Meaning: #{card.description}\n"

        # Add numerological information if available
        if numerology[:number]
          card_info += "Numerology: #{numerology[:number]} - #{numerology[:meaning]}\n"
        end

        # Add elemental information if available
        if arcana_info[:element]
          card_info += "Element: #{arcana_info[:element]}\n"
        end

        card_info + "\n"
      end.join

      question_text = context[:question].present? ? "Career question: #{context[:question]}\n\n" : ""

      # Calculate overall elemental balance
      elements = context[:cards].map { |card| ArcanaService.get_elemental_association(card.name) }.compact
      element_counts = elements.group_by { |e| e }.transform_values(&:count)
      elemental_text = "Elemental Balance:\n"
      element_counts.each do |element, count|
        percentage = (count.to_f / elements.length * 100).round
        elemental_text += "- #{element}: #{percentage}%\n"
      end
      elemental_text += "\n"

      <<~PROMPT
        interpret this career guidance tarot reading:

        #{question_text}#{elemental_text}#{cards_info}

        provide insights that help understand career path and make informed professional decisions.
        analyze the elemental balance and what it suggests about the querent's career situation.
        consider numerological timing factors in your guidance.
        suggest specific action steps to improve professional life.
      PROMPT
    end

    def build_personal_development_user_prompt(context)
      cards_info = context[:cards].map.with_index do |card, i|
        position = context[:positions][i]

        # Get additional information about the card
        numerology = NumerologyService.get_card_numerology(card.name)
        arcana_info = ArcanaService.get_card_info(card.name)

        card_info = "Position: #{position["name"]} - #{position["description"]}\n" \
                    "Card: #{card.name}#{context[:is_reversed] ? " (Reversed)" : ""}\n" \
                    "Card Meaning: #{card.description}\n"

        # Add numerological information if available
        if numerology[:number]
          card_info += "Numerology: #{numerology[:number]} - #{numerology[:meaning]}\n"
        end

        # Add elemental information if available
        if arcana_info[:element]
          card_info += "Element: #{arcana_info[:element]}\n"
        end

        # Add keywords
        keywords = ArcanaService.get_card_keywords(card.name)
        card_info += "Keywords: #{keywords.join(', ')}\n" unless keywords.empty?

        card_info + "\n"
      end.join

      question_text = context[:question].present? ? "Personal development question: #{context[:question]}\n\n" : ""

      <<~PROMPT
        interpret this personal development tarot reading:

        #{question_text}#{cards_info}

        provide insights that help understand strengths, challenges, and opportunities for growth.
        identify archetypal patterns present in the reading and their significance.
        analyze symbolic connections between the cards.
        suggest specific action steps for personal development.
      PROMPT
    end
  end
end
