class SymbolismService
  UNIVERSAL_SYMBOLS = {
    animals: {
      lion: "Strength, courage, pride, royalty",
      eagle: "Vision, freedom, spiritual ascension",
      snake: "Transformation, healing, wisdom, rebirth",
      dog: "Loyalty, protection, companionship",
      wolf: "Instinct, intelligence, freedom, social connection",
      horse: "Freedom, power, movement, desire",
      butterfly: "Transformation, soul, resurrection",
      owl: "Wisdom, intuition, seeing through deception",
      fish: "Unconscious mind, fertility, abundance",
      dove: "Peace, purity, divine messenger"
    },
    
    colors: {
      red: "Passion, energy, action, power, danger",
      blue: "Peace, tranquility, depth, wisdom, truth",
      yellow: "Intellect, joy, optimism, enlightenment",
      green: "Growth, harmony, fertility, abundance",
      purple: "Spirituality, mystery, transformation, royalty",
      white: "Purity, innocence, clarity, potential",
      black: "Mystery, unconscious, protection, transformation",
      gold: "Divinity, enlightenment, wisdom, value",
      silver: "Intuition, reflection, moon energy, feminine"
    },
    
    elements: {
      fire: "Transformation, energy, passion, inspiration",
      water: "Emotions, intuition, healing, purification",
      air: "Intellect, communication, freedom, clarity",
      earth: "Stability, growth, abundance, practicality",
      spirit: "Connection, transcendence, wholeness, divinity"
    },
    
    celestial: {
      sun: "Vitality, clarity, success, enlightenment",
      moon: "Intuition, cycles, emotions, unconscious",
      stars: "Hope, guidance, inspiration, destiny",
      planets: "Cosmic forces, fate, universal energies"
    },
    
    numbers: {
      one: "Unity, beginnings, individuality, leadership",
      two: "Duality, partnership, balance, choice",
      three: "Creation, expression, growth, synthesis",
      four: "Stability, structure, foundation, order",
      five: "Change, freedom, conflict, adaptation",
      six: "Harmony, balance, responsibility, love",
      seven: "Mystery, spirituality, wisdom, introspection",
      eight: "Power, abundance, infinity, regeneration",
      nine: "Completion, fulfillment, wisdom, integration",
      ten: "Completion of a cycle, perfection, return to one",
      zero: "Potential, wholeness, infinity, the void"
    },
    
    objects: {
      sword: "Intellect, truth, division, courage",
      cup: "Emotions, intuition, relationships, fulfillment",
      wand: "Energy, creativity, passion, potential",
      pentacle: "Material world, manifestation, abundance",
      key: "Access, opportunity, knowledge, solution",
      book: "Wisdom, learning, record, memory",
      mirror: "Reflection, truth, self-awareness",
      door: "Opportunity, transition, choice, threshold",
      crown: "Authority, achievement, leadership, higher consciousness",
      wheel: "Cycles, fate, movement, karma"
    },
    
    nature: {
      mountain: "Achievement, perspective, challenge, stability",
      river: "Journey, emotions, time, cleansing",
      tree: "Growth, connection, wisdom, life cycles",
      flower: "Beauty, growth, opening, potential",
      seed: "Potential, beginnings, dormancy, essence",
      ocean: "Unconscious, depth, mystery, origin",
      forest: "Unconscious, mystery, transition, wildness",
      desert: "Purification, emptiness, challenge, clarity",
      garden: "Cultivation, abundance, paradise, order"
    },
    
    directions: {
      up: "Ascension, improvement, heaven, consciousness",
      down: "Descent, unconscious, earth, grounding",
      left: "Past, intuition, feminine, receptive",
      right: "Future, action, masculine, giving",
      center: "Balance, integration, self, present moment"
    },
    
    body: {
      eyes: "Vision, awareness, perception, wisdom",
      hands: "Creation, action, connection, giving/receiving",
      heart: "Love, emotion, courage, center",
      head: "Intellect, leadership, identity, consciousness",
      feet: "Grounding, journey, foundation, direction"
    }
  }
  
  CARD_COMBINATIONS = {
    complementary: [
      { cards: ["The Fool", "The World"], meaning: "Beginning and completion of a journey" },
      { cards: ["The Magician", "The High Priestess"], meaning: "Balance of active and receptive energies" },
      { cards: ["The Empress", "The Emperor"], meaning: "Balance of feminine and masculine energies" },
      { cards: ["The Hierophant", "The Hermit"], meaning: "External and internal wisdom" },
      { cards: ["The Lovers", "The Devil"], meaning: "Freedom of choice versus bondage" },
      { cards: ["The Chariot", "Temperance"], meaning: "Control versus balance" },
      { cards: ["Strength", "The Tower"], meaning: "Inner versus external power" },
      { cards: ["The Star", "The Moon"], meaning: "Hope versus fear" },
      { cards: ["The Sun", "Judgement"], meaning: "Joy versus accountability" },
      { cards: ["Death", "The Wheel of Fortune"], meaning: "Inevitable change versus cyclical change" }
    ],
    
    challenging: [
      { cards: ["The Fool", "The Devil"], meaning: "Innocence corrupted or tested" },
      { cards: ["The Magician", "The Moon"], meaning: "Deception or illusion in manifestation" },
      { cards: ["The High Priestess", "The Emperor"], meaning: "Intuition restricted by structure" },
      { cards: ["The Empress", "Death"], meaning: "Creation facing transformation" },
      { cards: ["The Hierophant", "The Tower"], meaning: "Tradition disrupted by sudden change" },
      { cards: ["The Lovers", "The Hermit"], meaning: "Partnership versus solitude" },
      { cards: ["The Chariot", "The Hanged Man"], meaning: "Forward movement versus surrender" },
      { cards: ["Strength", "The Star"], meaning: "Inner power versus hope for external help" },
      { cards: ["The Wheel of Fortune", "Justice"], meaning: "Fate versus fairness" },
      { cards: ["Death", "The Sun"], meaning: "Endings versus vitality" }
    ],
    
    reinforcing: [
      { cards: ["The Fool", "The Star"], meaning: "Optimistic new beginnings" },
      { cards: ["The Magician", "The Sun"], meaning: "Powerful manifestation" },
      { cards: ["The High Priestess", "The Moon"], meaning: "Deep intuition and psychic ability" },
      { cards: ["The Empress", "The World"], meaning: "Abundant completion" },
      { cards: ["The Emperor", "Justice"], meaning: "Fair authority and structure" },
      { cards: ["The Hierophant", "Judgement"], meaning: "Spiritual awakening through tradition" },
      { cards: ["The Lovers", "Temperance"], meaning: "Balanced and harmonious relationships" },
      { cards: ["The Chariot", "Strength"], meaning: "Powerful forward movement" },
      { cards: ["The Hermit", "The Hanged Man"], meaning: "Deep introspection and new perspective" },
      { cards: ["The Wheel of Fortune", "Death"], meaning: "Profound and inevitable change" }
    ]
  }
  
  ELEMENTAL_COMBINATIONS = {
    fire_fire: "Intensified passion, creativity, and energy. Can indicate burnout if not balanced.",
    fire_water: "Steam - emotional transformation, passion meeting feeling, potential conflict.",
    fire_air: "Fanned flames - accelerated ideas, communication energizing action.",
    fire_earth: "Contained fire - practical creativity, grounded passion, sustainable energy.",
    
    water_water: "Deep emotions, intuitive flow, potential for emotional overwhelm.",
    water_air: "Mist - ideas born from feelings, communication about emotions.",
    water_earth: "Growth - emotional stability, nurturing practical matters.",
    
    air_air: "Intensified thought, communication, potential for overthinking.",
    air_earth: "Practical ideas, grounded thinking, plans becoming reality.",
    
    earth_earth: "Stability, abundance, material focus, potential for stagnation."
  }
  
  class << self
    def get_symbol_meaning(symbol_type, symbol)
      category = UNIVERSAL_SYMBOLS[symbol_type.to_sym]
      return nil unless category
      
      category[symbol.to_sym]
    end
    
    def analyze_card_combination(card1, card2)
      # Check for known combinations
      CARD_COMBINATIONS.each do |type, combinations|
        combinations.each do |combo|
          if (combo[:cards].include?(card1) && combo[:cards].include?(card2))
            return { type: type, meaning: combo[:meaning] }
          end
        end
      end
      
      # If no predefined combination, analyze by arcana type
      if ArcanaService.is_major_arcana?(card1) && ArcanaService.is_major_arcana?(card2)
        return { type: :major_major, meaning: "Significant forces at work, important life themes" }
      elsif !ArcanaService.is_major_arcana?(card1) && !ArcanaService.is_major_arcana?(card2)
        return { type: :minor_minor, meaning: "Day-to-day situations, practical matters" }
      else
        return { type: :major_minor, meaning: "Important theme manifesting in everyday life" }
      end
    end
    
    def analyze_elemental_combination(card1, card2)
      element1 = ArcanaService.get_elemental_association(card1)
      element2 = ArcanaService.get_elemental_association(card2)
      
      return nil unless element1 && element2
      
      elements = [element1.downcase, element2.downcase].sort.join('_')
      ELEMENTAL_COMBINATIONS[elements.to_sym]
    end
    
    def identify_symbols_in_card(card_name)
      # Get card symbolism from ArcanaService
      card_symbolism = ArcanaService.get_card_symbolism(card_name)
      
      # Identify universal symbols present in the card
      universal_symbols = {}
      
      UNIVERSAL_SYMBOLS.each do |category, symbols|
        found_symbols = {}
        
        symbols.each do |symbol, meaning|
          # Check if the symbol is mentioned in the card's symbolism
          card_symbolism.each do |card_symbol, _|
            if card_symbol.to_s.include?(symbol.to_s) || symbol.to_s.include?(card_symbol.to_s)
              found_symbols[symbol] = meaning
              break
            end
          end
        end
        
        universal_symbols[category] = found_symbols unless found_symbols.empty?
      end
      
      {
        card_specific: card_symbolism,
        universal: universal_symbols
      }
    end
    
    def get_numerological_symbolism(card_name)
      # Get numerological information from NumerologyService
      numerology = NumerologyService.get_card_numerology(card_name)
      
      # Get number symbolism
      number = numerology[:number]
      return nil unless number
      
      number_word = case number
                    when 0 then :zero
                    when 1 then :one
                    when 2 then :two
                    when 3 then :three
                    when 4 then :four
                    when 5 then :five
                    when 6 then :six
                    when 7 then :seven
                    when 8 then :eight
                    when 9 then :nine
                    when 10 then :ten
                    else nil
                    end
      
      return nil unless number_word
      
      {
        number: number,
        symbolism: UNIVERSAL_SYMBOLS[:numbers][number_word]
      }
    end
    
    def analyze_spread_pattern(card_positions)
      # Analyze the geometric pattern of the spread
      case card_positions.length
      when 1
        { pattern: "single", meaning: "Focus on a single issue or energy" }
      when 2
        { pattern: "binary", meaning: "Duality, choice, or balance between two forces" }
      when 3
        { pattern: "triangle", meaning: "Synthesis, creation, past-present-future" }
      when 4
        { pattern: "square", meaning: "Stability, foundation, structure" }
      when 5
        { pattern: "pentagram", meaning: "Balance of elements, protection, wholeness" }
      when 6
        { pattern: "hexagram", meaning: "Harmony, balance of opposing forces" }
      when 7
        { pattern: "septagram", meaning: "Mystical insight, spiritual awareness" }
      when 10
        { pattern: "tree of life", meaning: "Complete spiritual journey, cosmic order" }
      else
        { pattern: "complex", meaning: "Multi-faceted situation with many influences" }
      end
    end
    
    def get_color_symbolism(color)
      UNIVERSAL_SYMBOLS[:colors][color.to_sym]
    end
    
    def get_element_symbolism(element)
      UNIVERSAL_SYMBOLS[:elements][element.to_sym]
    end
  end
end 