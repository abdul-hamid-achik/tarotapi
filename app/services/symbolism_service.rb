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
      { cards: [ "The Fool", "The World" ], meaning: "Beginning and completion of a journey" },
      { cards: [ "The Magician", "The High Priestess" ], meaning: "Balance of active and receptive energies" },
      { cards: [ "The Empress", "The Emperor" ], meaning: "Balance of feminine and masculine energies" },
      { cards: [ "The Hierophant", "The Hermit" ], meaning: "External and internal wisdom" },
      { cards: [ "The Lovers", "The Devil" ], meaning: "Freedom of choice versus bondage" },
      { cards: [ "The Chariot", "Temperance" ], meaning: "Control versus balance" },
      { cards: [ "Strength", "The Tower" ], meaning: "Inner versus external power" },
      { cards: [ "The Star", "The Moon" ], meaning: "Hope versus fear" },
      { cards: [ "The Sun", "Judgement" ], meaning: "Joy versus accountability" },
      { cards: [ "Death", "The Wheel of Fortune" ], meaning: "Inevitable change versus cyclical change" }
    ],

    challenging: [
      { cards: [ "The Fool", "The Devil" ], meaning: "Innocence corrupted or tested" },
      { cards: [ "The Magician", "The Moon" ], meaning: "Deception or illusion in manifestation" },
      { cards: [ "The High Priestess", "The Emperor" ], meaning: "Intuition restricted by structure" },
      { cards: [ "The Empress", "Death" ], meaning: "Creation facing transformation" },
      { cards: [ "The Hierophant", "The Tower" ], meaning: "Tradition disrupted by sudden change" },
      { cards: [ "The Lovers", "The Hermit" ], meaning: "Partnership versus solitude" },
      { cards: [ "The Chariot", "The Hanged Man" ], meaning: "Forward movement versus surrender" },
      { cards: [ "Strength", "The Star" ], meaning: "Inner power versus hope for external help" },
      { cards: [ "The Wheel of Fortune", "Justice" ], meaning: "Fate versus fairness" },
      { cards: [ "Death", "The Sun" ], meaning: "Endings versus vitality" }
    ],

    reinforcing: [
      { cards: [ "The Fool", "The Star" ], meaning: "Optimistic new beginnings" },
      { cards: [ "The Magician", "The Sun" ], meaning: "Powerful manifestation" },
      { cards: [ "The High Priestess", "The Moon" ], meaning: "Deep intuition and psychic ability" },
      { cards: [ "The Empress", "The World" ], meaning: "Abundant completion" },
      { cards: [ "The Emperor", "Justice" ], meaning: "Fair authority and structure" },
      { cards: [ "The Hierophant", "Judgement" ], meaning: "Spiritual awakening through tradition" },
      { cards: [ "The Lovers", "Temperance" ], meaning: "Balanced and harmonious relationships" },
      { cards: [ "The Chariot", "Strength" ], meaning: "Powerful forward movement" },
      { cards: [ "The Hermit", "The Hanged Man" ], meaning: "Deep introspection and new perspective" },
      { cards: [ "The Wheel of Fortune", "Death" ], meaning: "Profound and inevitable change" }
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
      # Analyze the relationship between two cards
      if is_opposing_pair?(card1, card2)
        { type: "opposition", meaning: "These cards represent opposing forces or energies that need to be balanced." }
      elsif is_complementary_pair?(card1, card2)
        { type: "complementary", meaning: "These cards complement each other, suggesting harmony and reinforcement." }
      elsif is_sequential_pair?(card1, card2)
        { type: "sequential", meaning: "These cards form a natural progression, suggesting development or evolution." }
      else
        { type: "neutral", meaning: "These cards have no specific inherent relationship but should be interpreted together in context." }
      end
    end

    def analyze_elemental_combination(card1, card2)
      # Get the elements associated with each card
      element1 = get_card_element(card1)
      element2 = get_card_element(card2)

      if element1 == element2
        "These cards share the same elemental energy (#{element1}), reinforcing each other's qualities."
      else
        case [ element1, element2 ].sort.join("_")
        when "air_fire"
          "Air feeds Fire, suggesting that thoughts and communication enhance passion and creativity."
        when "air_water"
          "Air and Water can create storms, suggesting emotional turbulence or deep intuitive insights."
        when "air_earth"
          "Air and Earth have less natural affinity, suggesting a need to balance ideas with practicality."
        when "earth_fire"
          "Earth contains Fire, suggesting a need to ground passion with practicality."
        when "earth_water"
          "Earth and Water together are fertile, suggesting growth, nurturing, and productivity."
        when "fire_water"
          "Fire and Water oppose each other, suggesting internal conflict or transformative energy."
        else
          "These elements interact in complex ways, suggesting nuanced energies at play."
        end
      end
    end

    def analyze_spread_pattern(cards)
      # Analyze patterns across all cards in a spread

      # Count card types
      major_count = cards.count { |c| c.arcana&.downcase == "major" }
      minor_count = cards.count { |c| c.arcana&.downcase == "minor" }

      # Count elements
      elements = cards.map { |c| get_card_element(c.name) }
      dominant_element = elements.tally.max_by { |_, count| count }&.first

      # Count reversed cards
      # Note: This would need to be passed in from the card_readings if implemented

      {
        major_arcana_count: major_count,
        minor_arcana_count: minor_count,
        dominant_element: dominant_element,
        element_balance: elements.tally,
        pattern_description: generate_pattern_description(major_count, minor_count, dominant_element)
      }
    end

    def identify_symbols_in_card(card_name)
      # Return common symbols associated with each card
      case card_name.to_s.downcase
      when /fool/
        [ "cliff", "small dog", "knapsack", "white rose", "mountains", "sun" ]
      when /magician/
        [ "infinity symbol", "table", "pentacle", "cup", "sword", "wand", "lemniscate" ]
      when /high priestess/
        [ "moon crown", "veil", "pillars", "pomegranates", "scroll", "water" ]
      when /empress/
        [ "crown of stars", "venus symbol", "cushion", "heart", "wheat", "trees", "waterfall" ]
      when /emperor/
        [ "throne", "ram heads", "ankh scepter", "red robe", "mountains", "armor" ]
      when /hierophant/
        [ "triple crown", "staff", "two acolytes", "keys", "pillars", "religious symbols" ]
      when /lovers/
        [ "angel", "man", "woman", "tree", "serpent", "flames", "mountains" ]
      when /chariot/
        [ "chariot", "sphinxes", "armor", "square", "staff", "stars", "crown", "city" ]
      when /strength/
        [ "lion", "infinity symbol", "woman", "flowers", "white dress", "mountains" ]
      when /hermit/
        [ "lantern", "staff", "gray robe", "snow", "mountains", "star", "hood" ]
      when /wheel of fortune/
        [ "wheel", "sphinx", "anubis", "serpent", "four figures", "hebrew letters", "clouds" ]
      when /justice/
        [ "scales", "sword", "throne", "crown", "pillars", "square" ]
      when /hanged man/
        [ "gallows", "upside-down man", "halo", "crossed legs", "blue clothing", "rope" ]
      when /death/
        [ "skeleton", "armor", "horse", "flag", "bodies", "sunset", "boat", "river" ]
      when /temperance/
        [ "angel", "cups", "flowing water", "path", "mountains", "sun", "crown", "wings" ]
      when /devil/
        [ "horns", "wings", "pentagram", "chains", "naked figures", "tail", "altar", "torch" ]
      when /tower/
        [ "lightning", "crown", "falling people", "flames", "rocks", "waves", "darkness" ]
      when /star/
        [ "nude woman", "seven stars", "two vessels", "bird", "pool", "land", "tree" ]
      when /moon/
        [ "moon", "dog and wolf", "crawfish", "water", "path", "towers", "drops" ]
      when /sun/
        [ "sun", "child", "horse", "sunflowers", "wall", "rays", "flag" ]
      when /judgement/
        [ "angel", "trumpet", "figures rising", "waves", "coffins", "mountains", "clouds" ]
      when /world/
        [ "dancing figure", "wreath", "four figures", "wand", "sky", "clouds", "stars" ]
      else
        # For minor arcana or unknown cards, return generic symbols
        if card_name.match?(/(\w+) of (\w+)/)
          rank, suit = card_name.split(" of ")
          suit_symbols = case suit.downcase
          when "wands"
                           [ "staffs", "fire", "growth", "energy" ]
          when "cups"
                           [ "chalices", "water", "emotions", "relationships" ]
          when "swords"
                           [ "blades", "air", "thought", "conflict" ]
          when "pentacles"
                           [ "coins", "earth", "material", "work" ]
          else
                           [ "unknown suit" ]
          end

          rank_symbols = case rank.downcase
          when "ace"
                           [ "single", "beginning", "potential" ]
          when "two"
                           [ "balance", "duality", "choice" ]
          when "three"
                           [ "creation", "growth", "collaboration" ]
          when "four"
                           [ "stability", "foundation", "structure" ]
          when "five"
                           [ "conflict", "challenge", "change" ]
          when "six"
                           [ "harmony", "cooperation", "transition" ]
          when "seven"
                           [ "reflection", "assessment", "vision" ]
          when "eight"
                           [ "movement", "progress", "speed" ]
          when "nine"
                           [ "fruition", "culmination", "readiness" ]
          when "ten"
                           [ "completion", "fulfillment", "ending" ]
          when "page"
                           [ "youth", "student", "messenger" ]
          when "knight"
                           [ "action", "adventure", "pursuit" ]
          when "queen"
                           [ "nurturing", "intuition", "inner power" ]
          when "king"
                           [ "mastery", "authority", "control" ]
          else
                           [ "unknown rank" ]
          end

          suit_symbols + rank_symbols
        else
          [ "unknown card" ]
        end
      end
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

    def get_color_symbolism(color)
      UNIVERSAL_SYMBOLS[:colors][color.to_sym]
    end

    def get_element_symbolism(element)
      UNIVERSAL_SYMBOLS[:elements][element.to_sym]
    end

    private

    def is_opposing_pair?(card1, card2)
      opposing_pairs = [
        [ "the fool", "the world" ],
        [ "the magician", "the high priestess" ],
        [ "the empress", "the emperor" ],
        [ "the hierophant", "the lovers" ],
        [ "the chariot", "the hermit" ],
        [ "wheel of fortune", "justice" ],
        [ "the hanged man", "death" ],
        [ "temperance", "the devil" ],
        [ "the tower", "the star" ],
        [ "the moon", "the sun" ]
      ]

      card1_lower = card1.to_s.downcase
      card2_lower = card2.to_s.downcase

      opposing_pairs.any? do |pair|
        (pair[0] == card1_lower && pair[1] == card2_lower) ||
        (pair[0] == card2_lower && pair[1] == card1_lower)
      end
    end

    def is_complementary_pair?(card1, card2)
      complementary_pairs = [
        [ "the magician", "the sun" ],
        [ "the high priestess", "the moon" ],
        [ "the empress", "temperance" ],
        [ "the emperor", "justice" ],
        [ "the hierophant", "judgement" ],
        [ "the lovers", "the world" ],
        [ "the chariot", "strength" ],
        [ "the hermit", "the star" ],
        [ "wheel of fortune", "the world" ],
        [ "the hanged man", "the star" ],
        [ "death", "judgement" ],
        [ "the devil", "the tower" ]
      ]

      card1_lower = card1.to_s.downcase
      card2_lower = card2.to_s.downcase

      complementary_pairs.any? do |pair|
        (pair[0] == card1_lower && pair[1] == card2_lower) ||
        (pair[0] == card2_lower && pair[1] == card1_lower)
      end
    end

    def is_sequential_pair?(card1, card2)
      # Check if cards are sequential in the major arcana
      major_arcana = [
        "the fool", "the magician", "the high priestess", "the empress", "the emperor",
        "the hierophant", "the lovers", "the chariot", "strength", "the hermit",
        "wheel of fortune", "justice", "the hanged man", "death", "temperance",
        "the devil", "the tower", "the star", "the moon", "the sun", "judgement", "the world"
      ]

      card1_lower = card1.to_s.downcase
      card2_lower = card2.to_s.downcase

      card1_index = major_arcana.index(card1_lower)
      card2_index = major_arcana.index(card2_lower)

      if card1_index && card2_index
        (card1_index - card2_index).abs == 1
      else
        false
      end
    end

    def get_card_element(card_name)
      card_lower = card_name.to_s.downcase

      # Major Arcana
      case card_lower
      when "the fool", "the magician", "the emperor", "the hierophant",
           "the chariot", "justice", "death", "temperance", "the sun", "judgement"
        "fire"
      when "the high priestess", "the empress", "the lovers",
           "the hanged man", "the moon"
        "water"
      when "the hermit", "wheel of fortune", "the devil",
           "the star", "the world"
        "earth"
      when "strength", "the tower"
        "air"
      else
        # Minor Arcana
        if card_lower.include?("wands")
          "fire"
        elsif card_lower.include?("cups")
          "water"
        elsif card_lower.include?("swords")
          "air"
        elsif card_lower.include?("pentacles") || card_lower.include?("coins")
          "earth"
        else
          "unknown"
        end
      end
    end

    def generate_pattern_description(major_count, minor_count, dominant_element)
      description = []

      # Analyze major/minor balance
      if major_count > minor_count * 2
        description << "This spread is heavily dominated by Major Arcana cards, suggesting significant life events and powerful external forces at work."
      elsif major_count > minor_count
        description << "There are more Major Arcana than Minor Arcana cards, suggesting important life themes and decisions are prominent."
      elsif major_count == 0
        description << "The absence of Major Arcana cards suggests this relates to everyday matters rather than major life events."
      elsif minor_count == 0
        description << "The spread contains only Major Arcana cards, indicating profound life changes and spiritual significance."
      else
        description << "The balance between Major and Minor Arcana suggests a mix of everyday concerns and significant life themes."
      end

      # Analyze elemental balance
      if dominant_element
        case dominant_element
        when "fire"
          description << "Fire dominates this spread, suggesting themes of energy, passion, creativity, and transformation."
        when "water"
          description << "Water dominates this spread, suggesting themes of emotion, intuition, relationships, and the subconscious."
        when "air"
          description << "Air dominates this spread, suggesting themes of intellect, communication, conflict, and mental activity."
        when "earth"
          description << "Earth dominates this spread, suggesting themes of practicality, work, material concerns, and stability."
        end
      else
        description << "The elements are relatively balanced, suggesting a holistic situation involving multiple aspects of life."
      end

      description.join(" ")
    end
  end
end
