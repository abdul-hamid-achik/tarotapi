class NumerologyService
  LIFE_PATH_MEANINGS = {
    1 => {
      name: "The Leader",
      description: "Independent, pioneering, ambitious, and determined. Natural leaders who forge their own path.",
      strengths: "Leadership, innovation, independence, courage",
      challenges: "Stubbornness, dominance, impatience"
    },
    2 => {
      name: "The Mediator",
      description: "Cooperative, diplomatic, sensitive, and balanced. Natural peacemakers who excel at partnerships.",
      strengths: "Diplomacy, intuition, cooperation, sensitivity",
      challenges: "Oversensitivity, indecision, dependency"
    },
    3 => {
      name: "The Communicator",
      description: "Expressive, creative, social, and optimistic. Natural entertainers who inspire others.",
      strengths: "Creativity, expression, joy, inspiration",
      challenges: "Scattered energy, superficiality, criticism"
    },
    4 => {
      name: "The Builder",
      description: "Practical, reliable, disciplined, and hardworking. Natural organizers who create solid foundations.",
      strengths: "Reliability, practicality, organization, determination",
      challenges: "Rigidity, stubbornness, limitation"
    },
    5 => {
      name: "The Freedom Seeker",
      description: "Adaptable, versatile, curious, and adventurous. Natural explorers who embrace change.",
      strengths: "Adaptability, versatility, resourcefulness, freedom",
      challenges: "Restlessness, inconsistency, excess"
    },
    6 => {
      name: "The Nurturer",
      description: "Responsible, caring, compassionate, and harmonious. Natural caregivers who create balance.",
      strengths: "Responsibility, nurturing, harmony, service",
      challenges: "Self-sacrifice, perfectionism, interference"
    },
    7 => {
      name: "The Seeker",
      description: "Analytical, introspective, spiritual, and wise. Natural philosophers who seek deeper truths.",
      strengths: "Analysis, wisdom, intuition, spirituality",
      challenges: "Isolation, overthinking, skepticism"
    },
    8 => {
      name: "The Achiever",
      description: "Ambitious, powerful, confident, and authoritative. Natural executives who manifest abundance.",
      strengths: "Ambition, organization, practicality, leadership",
      challenges: "Workaholic tendencies, materialism, control"
    },
    9 => {
      name: "The Humanitarian",
      description: "Compassionate, idealistic, selfless, and creative. Natural healers who serve the greater good.",
      strengths: "Compassion, generosity, wisdom, creativity",
      challenges: "Martyrdom, aloofness, resentment"
    },
    11 => {
      name: "The Intuitive",
      description: "Inspirational, intuitive, idealistic, and visionary. Natural channels for spiritual wisdom.",
      strengths: "Intuition, inspiration, idealism, sensitivity",
      challenges: "Nervous tension, impracticality, emotional extremes"
    },
    22 => {
      name: "The Master Builder",
      description: "Practical, visionary, powerful, and accomplished. Natural manifestors who create lasting structures.",
      strengths: "Vision, practicality, leadership, manifestation",
      challenges: "Overwhelming responsibility, perfectionism, burnout"
    },
    33 => {
      name: "The Master Teacher",
      description: "Compassionate, nurturing, inspiring, and selfless. Natural healers who uplift humanity.",
      strengths: "Compassion, healing, inspiration, creativity",
      challenges: "Self-sacrifice, unrealistic expectations, emotional burden"
    }
  }

  TAROT_NUMEROLOGY = {
    1 => {
      meaning: "New beginnings, independence, individuality",
      cards: [ "The Magician", "Wheel of Fortune", "The Sun" ]
    },
    2 => {
      meaning: "Balance, partnership, duality",
      cards: [ "The High Priestess", "Justice", "Judgement" ]
    },
    3 => {
      meaning: "Creativity, expression, growth",
      cards: [ "The Empress", "The Hanged Man", "The World" ]
    },
    4 => {
      meaning: "Stability, structure, foundation",
      cards: [ "The Emperor", "Death" ]
    },
    5 => {
      meaning: "Change, freedom, adventure",
      cards: [ "The Hierophant", "The Tower" ]
    },
    6 => {
      meaning: "Harmony, responsibility, love",
      cards: [ "The Lovers", "The Devil" ]
    },
    7 => {
      meaning: "Spirituality, wisdom, introspection",
      cards: [ "The Chariot", "The Star" ]
    },
    8 => {
      meaning: "Power, abundance, achievement",
      cards: [ "Strength", "The Moon" ]
    },
    9 => {
      meaning: "Completion, fulfillment, universal love",
      cards: [ "The Hermit" ]
    },
    0 => {
      meaning: "Unlimited potential, wholeness, spiritual journey",
      cards: [ "The Fool" ]
    }
  }

  class << self
    def calculate_life_path_number(birth_date)
      # Convert birth_date to a string if it's a Date object
      date_string = birth_date.is_a?(Date) ? birth_date.strftime('%Y-%m-%d') : birth_date.to_s
      
      # Extract year, month, day from the date string
      parts = date_string.split(/[-\/]/).map(&:to_i)
      
      # Ensure we have 3 parts
      return nil unless parts.size == 3
      
      year, month, day = parts
      
      # Calculate the sum of all digits
      year_sum = sum_digits(year)
      month_sum = sum_digits(month)
      day_sum = sum_digits(day)
      
      # Sum the reduced numbers
      total_sum = year_sum + month_sum + day_sum
      
      # Reduce to a single digit (except master numbers 11, 22, 33)
      if total_sum == 11 || total_sum == 22 || total_sum == 33
        return total_sum
      else
        return reduce_to_single_digit(total_sum)
      end
    end
    
    def calculate_name_number(name)
      # Remove any non-alphabetic characters and convert to lowercase
      cleaned_name = name.to_s.gsub(/[^a-zA-Z]/, '').downcase
      
      # Sum the values of each letter in the name
      total = 0
      cleaned_name.each_char do |char|
        total += letter_value(char)
      end
      
      # Reduce to a single digit (except master numbers)
      if total == 11 || total == 22 || total == 33
        return total
      else
        return reduce_to_single_digit(total)
      end
    end
    
    def get_life_path_meaning(number)
      case number
      when 1
        "Independent, leader, original, self-sufficient"
      when 2
        "Cooperative, diplomat, sensitive, peacemaker"
      when 3
        "Creative, expressive, optimistic, social"
      when 4
        "Practical, reliable, stable, organized"
      when 5
        "Adventurous, versatile, freedom-loving, adaptable"
      when 6
        "Nurturing, responsible, service-oriented, supportive"
      when 7
        "Analytical, introspective, spiritual, knowledge-seeking"
      when 8
        "Ambitious, goal-oriented, influential, material mastery"
      when 9
        "Humanitarian, compassionate, global consciousness, artistic"
      when 11
        "Intuitive, idealistic, inspirational, visionary"
      when 22
        "Master builder, practical visionary, capable of manifestation"
      when 33
        "Master teacher, selfless service, highest spiritual wisdom"
      else
        "Unknown or invalid numerological path"
      end
    end
    
    def get_card_numerology(card_name)
      # Basic mapping of tarot cards to numerological meanings
      case card_name.to_s.downcase
      when /fool/, /jester/
        { number: 0, meaning: "New beginnings, unlimited potential" }
      when /magician/
        { number: 1, meaning: "Creation, willpower, manifestation" }
      when /high priestess/
        { number: 2, meaning: "Intuition, duality, receptivity" }
      when /empress/
        { number: 3, meaning: "Creation, fertility, abundance" }
      when /emperor/
        { number: 4, meaning: "Structure, stability, authority" }
      when /hierophant/
        { number: 5, meaning: "Tradition, spiritual guidance, conformity" }
      when /lovers/
        { number: 6, meaning: "Love, harmony, relationships" }
      when /chariot/
        { number: 7, meaning: "Direction, control, willpower" }
      when /strength/
        { number: 8, meaning: "Inner strength, courage, influence" }
      when /hermit/
        { number: 9, meaning: "Introspection, wisdom, solitude" }
      when /wheel of fortune/
        { number: 10, meaning: "Change, cycles, destiny" }
      when /justice/
        { number: 11, meaning: "Balance, fairness, truth" }
      when /hanged man/
        { number: 12, meaning: "Surrender, perspective, sacrifice" }
      when /death/
        { number: 13, meaning: "Transformation, endings, transition" }
      when /temperance/
        { number: 14, meaning: "Balance, moderation, harmony" }
      when /devil/
        { number: 15, meaning: "Materialism, bondage, addiction" }
      when /tower/
        { number: 16, meaning: "Sudden change, revelation, upheaval" }
      when /star/
        { number: 17, meaning: "Hope, faith, inspiration" }
      when /moon/
        { number: 18, meaning: "Intuition, illusion, subconscious" }
      when /sun/
        { number: 19, meaning: "Joy, success, vitality" }
      when /judgement/
        { number: 20, meaning: "Rebirth, inner calling, absolution" }
      when /world/
        { number: 21, meaning: "Completion, fulfillment, integration" }
      else
        # For minor arcana or unknown cards
        { number: nil, meaning: "No specific numerological association" }
      end
    end
    
    private
    
    def sum_digits(number)
      # Convert to string to handle digit by digit
      number.to_s.chars.map(&:to_i).sum
    end
    
    def reduce_to_single_digit(number)
      # Keep reducing until we get a single digit
      while number > 9
        number = sum_digits(number)
      end
      number
    end
    
    def letter_value(char)
      # Numerology assigns values 1-9 to letters A-Z
      # A=1, B=2, ..., I=9, J=1, ..., R=9, S=1, ...
      values = {
        'a' => 1, 'b' => 2, 'c' => 3, 'd' => 4, 'e' => 5,
        'f' => 6, 'g' => 7, 'h' => 8, 'i' => 9, 'j' => 1,
        'k' => 2, 'l' => 3, 'm' => 4, 'n' => 5, 'o' => 6,
        'p' => 7, 'q' => 8, 'r' => 9, 's' => 1, 't' => 2,
        'u' => 3, 'v' => 4, 'w' => 5, 'x' => 6, 'y' => 7,
        'z' => 8
      }
      values[char] || 0
    end
  end
end
