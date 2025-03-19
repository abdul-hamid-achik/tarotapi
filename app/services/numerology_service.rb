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
      # Convert birth_date to string if it's a Date object
      date_str = birth_date.is_a?(Date) ? birth_date.strftime("%Y%m%d") : birth_date.to_s.gsub(/\D/, "")

      # Extract year, month, day
      if date_str.length >= 8
        year = date_str[0..3]
        month = date_str[4..5]
        day = date_str[6..7]
      else
        # Handle different date formats
        parts = birth_date.to_s.split(/[-\/]/)
        if parts.length == 3
          year = parts[0].length == 4 ? parts[0] : parts[2]
          month = parts[1]
          day = parts[0].length == 4 ? parts[2] : parts[0]
        else
          return nil # Invalid date format
        end
      end

      # Calculate life path number
      year_num = reduce_to_single_digit(year)
      month_num = reduce_to_single_digit(month)
      day_num = reduce_to_single_digit(day)

      life_path = year_num + month_num + day_num

      # Reduce to single digit or master number
      final_number = reduce_to_single_or_master_number(life_path)

      final_number
    end

    def get_life_path_meaning(number)
      LIFE_PATH_MEANINGS[number] || {
        name: "Unknown",
        description: "No information available for this number.",
        strengths: "",
        challenges: ""
      }
    end

    def get_card_numerology(card_name)
      # Find the number associated with the card
      TAROT_NUMEROLOGY.each do |number, data|
        return { number: number, meaning: data[:meaning] } if data[:cards].include?(card_name)
      end

      # If not found in major arcana, check if it's a minor arcana card
      if card_name.match?(/(\w+) of (\w+)/)
        rank = card_name.split(" ").first

        case rank
        when "Ace"
          return { number: 1, meaning: TAROT_NUMEROLOGY[1][:meaning] }
        when "Two"
          return { number: 2, meaning: TAROT_NUMEROLOGY[2][:meaning] }
        when "Three"
          return { number: 3, meaning: TAROT_NUMEROLOGY[3][:meaning] }
        when "Four"
          return { number: 4, meaning: TAROT_NUMEROLOGY[4][:meaning] }
        when "Five"
          return { number: 5, meaning: TAROT_NUMEROLOGY[5][:meaning] }
        when "Six"
          return { number: 6, meaning: TAROT_NUMEROLOGY[6][:meaning] }
        when "Seven"
          return { number: 7, meaning: TAROT_NUMEROLOGY[7][:meaning] }
        when "Eight"
          return { number: 8, meaning: TAROT_NUMEROLOGY[8][:meaning] }
        when "Nine"
          return { number: 9, meaning: TAROT_NUMEROLOGY[9][:meaning] }
        when "Ten"
          return { number: 10, meaning: "Completion and new beginnings" }
        when "Page"
          return { number: 11, meaning: "New perspectives and learning" }
        when "Knight"
          return { number: 12, meaning: "Action and movement" }
        when "Queen"
          return { number: 13, meaning: "Nurturing mastery and receptivity" }
        when "King"
          return { number: 14, meaning: "Mastery and authority" }
        end
      end

      { number: nil, meaning: "Unknown numerological association" }
    end

    def calculate_name_number(name)
      # Remove spaces and convert to lowercase
      name = name.downcase.gsub(/\s+/, "")

      # Calculate the numerology value
      total = 0
      name.each_char do |char|
        total += letter_to_number(char)
      end

      # Reduce to single digit or master number
      reduce_to_single_or_master_number(total)
    end

    private

    def letter_to_number(letter)
      case letter.downcase
      when "a", "j", "s"
        1
      when "b", "k", "t"
        2
      when "c", "l", "u"
        3
      when "d", "m", "v"
        4
      when "e", "n", "w"
        5
      when "f", "o", "x"
        6
      when "g", "p", "y"
        7
      when "h", "q", "z"
        8
      when "i", "r"
        9
      else
        0 # For non-alphabetic characters
      end
    end

    def reduce_to_single_digit(number)
      # Convert to string to process each digit
      num_str = number.to_s

      # Sum all digits
      sum = 0
      num_str.each_char { |digit| sum += digit.to_i }

      # If sum is still more than one digit, reduce again
      if sum > 9
        reduce_to_single_digit(sum)
      else
        sum
      end
    end

    def reduce_to_single_or_master_number(number)
      # Convert to string to process each digit
      num_str = number.to_s

      # Check if it's already a single digit
      return number if num_str.length == 1

      # Check for master numbers
      return number if [ 11, 22, 33 ].include?(number)

      # Sum all digits
      sum = 0
      num_str.each_char { |digit| sum += digit.to_i }

      # Check if result is a master number
      return sum if [ 11, 22, 33 ].include?(sum)

      # If sum is still more than one digit, reduce again
      if sum > 9
        reduce_to_single_or_master_number(sum)
      else
        sum
      end
    end
  end
end
