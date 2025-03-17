class ArcanaService
  MAJOR_ARCANA = [
    {
      name: "The Fool",
      number: 0,
      element: nil,
      planet: "Uranus",
      zodiac: nil,
      keywords: ["beginnings", "innocence", "spontaneity", "free spirit"],
      symbolism: {
        cliff: "Leap of faith, risk-taking",
        white_rose: "Purity of intention",
        dog: "Loyalty, protection, instinct",
        mountains: "Challenges ahead",
        sun: "Enlightenment, vitality"
      }
    },
    {
      name: "The Magician",
      number: 1,
      element: "Air",
      planet: "Mercury",
      zodiac: nil,
      keywords: ["manifestation", "power", "action", "resourcefulness"],
      symbolism: {
        infinity_symbol: "Unlimited potential, eternal life",
        ouroboros_belt: "Continuity, self-sufficiency",
        red_white_robes: "Purity of wisdom and experience",
        tools: "Elements and resources at one's disposal",
        raised_wand: "Channel between heaven and earth"
      }
    },
    {
      name: "The High Priestess",
      number: 2,
      element: "Water",
      planet: "Moon",
      zodiac: nil,
      keywords: ["intuition", "unconscious", "divine feminine", "mystery"],
      symbolism: {
        moon_crown: "Intuition, psychic ability",
        pillars: "Duality, gateway to the unconscious",
        veil: "Hidden knowledge, mystery",
        scroll: "Wisdom, divine law",
        blue_robe: "Depth, tranquility, spiritual attainment"
      }
    },
    {
      name: "The Empress",
      number: 3,
      element: "Earth",
      planet: "Venus",
      zodiac: "Taurus/Libra",
      keywords: ["abundance", "fertility", "nurturing", "creativity"],
      symbolism: {
        crown_of_stars: "Connection to the heavens",
        venus_symbol: "Femininity, love, harmony",
        cushioned_throne: "Comfort, luxury",
        flowing_water: "Life, emotions, nurturing",
        lush_vegetation: "Growth, abundance, fertility"
      }
    },
    {
      name: "The Emperor",
      number: 4,
      element: "Fire",
      planet: "Mars",
      zodiac: "Aries",
      keywords: ["authority", "structure", "control", "leadership"],
      symbolism: {
        ram_heads: "Connection to Aries, determination",
        orb_and_scepter: "Authority, power",
        red_robe: "Passion, energy, action",
        stone_throne: "Stability, permanence",
        mountains: "Accomplishment, challenges overcome"
      }
    },
    {
      name: "The Hierophant",
      number: 5,
      element: "Earth",
      planet: nil,
      zodiac: "Taurus",
      keywords: ["tradition", "conformity", "morality", "ethics"],
      symbolism: {
        papal_cross: "Religious authority",
        triple_crown: "Three worlds (physical, mental, spiritual)",
        pillars: "Established institution, tradition",
        keys: "Keys to heaven, spiritual knowledge",
        acolytes: "Initiation, passing of knowledge"
      }
    },
    {
      name: "The Lovers",
      number: 6,
      element: "Air",
      planet: nil,
      zodiac: "Gemini",
      keywords: ["relationships", "choices", "alignment", "harmony"],
      symbolism: {
        angel: "Divine blessing, protection",
        man_and_woman: "Duality, partnership, union",
        tree_of_knowledge: "Temptation, consciousness",
        tree_of_life: "Spiritual fulfillment",
        snake: "Temptation, knowledge"
      }
    },
    {
      name: "The Chariot",
      number: 7,
      element: "Water",
      planet: nil,
      zodiac: "Cancer",
      keywords: ["control", "willpower", "victory", "assertion"],
      symbolism: {
        armor: "Protection, preparation",
        sphinxes: "Opposing forces, duality",
        chariot: "Vehicle of triumph, progress",
        star_canopy: "Celestial guidance",
        wand: "Will, direction, power"
      }
    },
    {
      name: "Strength",
      number: 8,
      element: "Fire",
      planet: nil,
      zodiac: "Leo",
      keywords: ["courage", "patience", "compassion", "soft control"],
      symbolism: {
        lion: "Raw passion, instinct, courage",
        woman: "Gentle strength, compassion",
        infinity_symbol: "Unlimited potential, balance",
        white_robe: "Purity of intention",
        flowers: "Beauty, growth, cultivation"
      }
    },
    {
      name: "The Hermit",
      number: 9,
      element: "Earth",
      planet: "Mercury",
      zodiac: "Virgo",
      keywords: ["introspection", "solitude", "guidance", "inner search"],
      symbolism: {
        lantern: "Light of truth, wisdom",
        staff: "Authority, support",
        gray_robe: "Neutrality, detachment",
        mountain: "Achievement, perspective",
        snow: "Purity, clarity"
      }
    },
    {
      name: "Wheel of Fortune",
      number: 10,
      element: nil,
      planet: "Jupiter",
      zodiac: nil,
      keywords: ["change", "cycles", "fate", "turning point"],
      symbolism: {
        wheel: "Cycles of life, karma",
        sphinx: "Wisdom, riddles of fate",
        creatures: "Fixed signs of the zodiac",
        hebrew_letters: "Name of God, divine plan",
        snake: "Life force, wisdom"
      }
    },
    {
      name: "Justice",
      number: 11,
      element: "Air",
      planet: nil,
      zodiac: "Libra",
      keywords: ["fairness", "truth", "law", "cause and effect"],
      symbolism: {
        scales: "Balance, fairness, karma",
        sword: "Truth, clarity, decision",
        crown: "Authority, higher consciousness",
        purple_robe: "Dignity, sovereignty",
        pillars: "Structure, stability, law"
      }
    },
    {
      name: "The Hanged Man",
      number: 12,
      element: "Water",
      planet: "Neptune",
      zodiac: nil,
      keywords: ["surrender", "new perspective", "enlightenment", "sacrifice"],
      symbolism: {
        inverted_position: "New perspective, reversal",
        t_shaped_cross: "Suffering, sacrifice",
        halo: "Enlightenment, divine wisdom",
        calm_face: "Peace through surrender",
        bound_leg: "Voluntary sacrifice"
      }
    },
    {
      name: "Death",
      number: 13,
      element: "Water",
      planet: "Pluto",
      zodiac: "Scorpio",
      keywords: ["transformation", "endings", "change", "transition"],
      symbolism: {
        skeleton: "What remains after transformation",
        black_armor: "Invincibility, protection",
        white_rose: "Purity, new beginnings",
        flag: "Transformation, victory",
        rising_sun: "Rebirth, new dawn"
      }
    },
    {
      name: "Temperance",
      number: 14,
      element: "Fire",
      planet: nil,
      zodiac: "Sagittarius",
      keywords: ["balance", "moderation", "patience", "purpose"],
      symbolism: {
        angel: "Divine guidance, balance",
        cups: "Flow of emotions, consciousness",
        water_and_land: "Subconscious and conscious",
        path: "Journey of life, purpose",
        triangle_in_square: "Spirit contained in matter"
      }
    },
    {
      name: "The Devil",
      number: 15,
      element: "Earth",
      planet: "Saturn",
      zodiac: "Capricorn",
      keywords: ["bondage", "materialism", "ignorance", "shadow self"],
      symbolism: {
        horns: "Animal nature, instinct",
        chains: "Self-imposed limitations",
        pentagram: "Material world, inverted priorities",
        naked_figures: "Vulnerability, exposure",
        raised_hand: "Blessing in disguise"
      }
    },
    {
      name: "The Tower",
      number: 16,
      element: "Fire",
      planet: "Mars",
      zodiac: nil,
      keywords: ["sudden change", "upheaval", "revelation", "awakening"],
      symbolism: {
        lightning: "Sudden illumination, divine intervention",
        crown: "False concepts, ego",
        falling_figures: "Forced removal from comfort",
        tower: "Constructed beliefs, false security",
        flames: "Destruction, purification"
      }
    },
    {
      name: "The Star",
      number: 17,
      element: "Air",
      planet: nil,
      zodiac: "Aquarius",
      keywords: ["hope", "faith", "renewal", "inspiration"],
      symbolism: {
        stars: "Guidance, divine inspiration",
        water: "Unconscious, emotions, life",
        nude_figure: "Vulnerability, authenticity",
        bird: "Soul, freedom",
        land_and_pool: "Material and spiritual worlds"
      }
    },
    {
      name: "The Moon",
      number: 18,
      element: "Water",
      planet: "Moon",
      zodiac: "Pisces",
      keywords: ["illusion", "fear", "anxiety", "subconscious"],
      symbolism: {
        moon: "Intuition, cycles, hidden influences",
        dog_and_wolf: "Domesticated and wild aspects of mind",
        crayfish: "Emergence from unconscious",
        towers: "Boundaries between conscious and unconscious",
        path: "Journey through the unknown"
      }
    },
    {
      name: "The Sun",
      number: 19,
      element: "Fire",
      planet: "Sun",
      zodiac: "Leo",
      keywords: ["joy", "success", "celebration", "vitality"],
      symbolism: {
        sun: "Vitality, clarity, truth",
        child: "Innocence, new beginnings",
        horse: "Strength, freedom, vitality",
        sunflowers: "Abundance, alignment",
        wall: "Boundary crossed, achievement"
      }
    },
    {
      name: "Judgement",
      number: 20,
      element: "Fire",
      planet: "Pluto",
      zodiac: nil,
      keywords: ["rebirth", "inner calling", "absolution", "awakening"],
      symbolism: {
        angel: "Divine messenger, higher calling",
        trumpet: "Awakening, announcement",
        rising_figures: "Resurrection, answering the call",
        mountains: "Challenges overcome",
        flag: "Victory, achievement"
      }
    },
    {
      name: "The World",
      number: 21,
      element: "Earth",
      planet: "Saturn",
      zodiac: nil,
      keywords: ["completion", "integration", "accomplishment", "travel"],
      symbolism: {
        dancing_figure: "Joy, freedom, completion",
        wreath: "Success, achievement, eternal cycle",
        four_figures: "Four elements, fixed signs of zodiac",
        wands: "Creation, manifestation",
        nudity: "Truth, authenticity"
      }
    }
  ]
  
  MINOR_ARCANA_SUITS = {
    wands: {
      element: "Fire",
      associations: ["creativity", "passion", "energy", "inspiration", "action"],
      symbolism: {
        staff: "Power, life force, creativity",
        leaves: "Growth, vitality",
        fire: "Transformation, energy"
      }
    },
    cups: {
      element: "Water",
      associations: ["emotions", "relationships", "intuition", "feelings", "love"],
      symbolism: {
        cup: "Vessel of emotions, the heart",
        water: "Feelings, intuition, flow",
        fish: "Unconscious mind, spiritual messages"
      }
    },
    swords: {
      element: "Air",
      associations: ["intellect", "communication", "conflict", "truth", "clarity"],
      symbolism: {
        sword: "Intellect, truth, division",
        clouds: "Thoughts, mental realm",
        birds: "Ideas, messages, freedom of thought"
      }
    },
    pentacles: {
      element: "Earth",
      associations: ["material world", "work", "body", "money", "practicality"],
      symbolism: {
        coin: "Material resources, manifestation",
        pentagram: "Physical world, four elements plus spirit",
        plants: "Growth, cultivation, patience"
      }
    }
  }
  
  COURT_CARDS = {
    page: {
      role: "Student",
      stage: "Beginning",
      qualities: ["curiosity", "learning", "messages", "exploration"]
    },
    knight: {
      role: "Seeker",
      stage: "Action",
      qualities: ["movement", "pursuit", "dedication", "adventure"]
    },
    queen: {
      role: "Manager",
      stage: "Nurturing",
      qualities: ["mastery", "nurturing", "expression", "inner focus"]
    },
    king: {
      role: "Leader",
      stage: "Authority",
      qualities: ["mastery", "control", "authority", "outer focus"]
    }
  }
  
  class << self
    def get_major_arcana_info(card_name)
      MAJOR_ARCANA.find { |card| card[:name].downcase == card_name.downcase } || {}
    end
    
    def get_minor_arcana_info(card_name)
      # Parse the card name to extract rank and suit
      # Example: "Three of Cups" -> rank: "Three", suit: "Cups"
      match_data = card_name.match(/(\w+) of (\w+)/)
      return {} unless match_data
      
      rank = match_data[1].downcase
      suit = match_data[2].downcase.to_sym
      
      # Get suit information
      suit_info = MINOR_ARCANA_SUITS[suit] || {}
      
      # Check if it's a court card
      court_info = if ["page", "knight", "queen", "king"].include?(rank)
        COURT_CARDS[rank.to_sym] || {}
      else
        {}
      end
      
      # Combine information
      {
        name: card_name,
        suit: suit.to_s.capitalize,
        rank: rank.capitalize,
        element: suit_info[:element],
        associations: suit_info[:associations],
        symbolism: suit_info[:symbolism],
        court_role: court_info[:role],
        court_stage: court_info[:stage],
        court_qualities: court_info[:qualities]
      }
    end
    
    def get_card_info(card_name)
      # Check if it's a major arcana card
      major_info = get_major_arcana_info(card_name)
      return major_info unless major_info.empty?
      
      # If not major arcana, check minor arcana
      get_minor_arcana_info(card_name)
    end
    
    def get_card_symbolism(card_name)
      card_info = get_card_info(card_name)
      card_info[:symbolism] || {}
    end
    
    def get_elemental_association(card_name)
      card_info = get_card_info(card_name)
      card_info[:element]
    end
    
    def get_astrological_association(card_name)
      card_info = get_card_info(card_name)
      {
        planet: card_info[:planet],
        zodiac: card_info[:zodiac]
      }
    end
    
    def is_major_arcana?(card_name)
      !get_major_arcana_info(card_name).empty?
    end
    
    def is_court_card?(card_name)
      match_data = card_name.match(/(\w+) of (\w+)/)
      return false unless match_data
      
      rank = match_data[1].downcase
      ["page", "knight", "queen", "king"].include?(rank)
    end
    
    def get_card_keywords(card_name)
      card_info = get_card_info(card_name)
      card_info[:keywords] || card_info[:associations] || card_info[:court_qualities] || []
    end
  end
end 