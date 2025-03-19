namespace :tarot do
  desc "seed tarot cards"
  task seed_cards: :environment do
    puts "seeding tarot cards..."

    # Only seed if no cards exist
    if TarotCard.count.zero?
      # Major Arcana (0-21)
      major_arcana = [
        { name: "the fool", number: 0, arcana: "major", suit: nil, meaning_upright: "Beginnings, innocence, spontaneity, a free spirit", meaning_reversed: "Holding back, recklessness, risk-taking" },
        { name: "the magician", number: 1, arcana: "major", suit: nil, meaning_upright: "Manifestation, resourcefulness, power, inspired action", meaning_reversed: "Manipulation, poor planning, untapped talents" },
        { name: "the high priestess", number: 2, arcana: "major", suit: nil, meaning_upright: "Intuition, sacred knowledge, divine feminine, the subconscious mind", meaning_reversed: "Secrets, disconnected from intuition, withdrawal and silence" },
        { name: "the empress", number: 3, arcana: "major", suit: nil, meaning_upright: "Femininity, beauty, nature, nurturing, abundance", meaning_reversed: "Creative block, dependence on others, over-nurturing" },
        { name: "the emperor", number: 4, arcana: "major", suit: nil, meaning_upright: "Authority, establishment, structure, a father figure", meaning_reversed: "Domination, excessive control, rigidity, inflexibility" },
        { name: "the hierophant", number: 5, arcana: "major", suit: nil, meaning_upright: "Spiritual wisdom, religious beliefs, conformity, tradition", meaning_reversed: "Personal beliefs, freedom, challenging the status quo" },
        { name: "the lovers", number: 6, arcana: "major", suit: nil, meaning_upright: "Love, harmony, relationships, values alignment, choices", meaning_reversed: "Self-love, disharmony, imbalance, misalignment of values" },
        { name: "the chariot", number: 7, arcana: "major", suit: nil, meaning_upright: "Control, willpower, success, action, determination", meaning_reversed: "Self-discipline, opposition, lack of direction" },
        { name: "strength", number: 8, arcana: "major", suit: nil, meaning_upright: "Strength, courage, persuasion, influence, compassion", meaning_reversed: "Inner strength, self-doubt, low energy, raw emotion" },
        { name: "the hermit", number: 9, arcana: "major", suit: nil, meaning_upright: "Soul-searching, introspection, being alone, inner guidance", meaning_reversed: "Isolation, loneliness, withdrawal" },
        { name: "wheel of fortune", number: 10, arcana: "major", suit: nil, meaning_upright: "Good luck, karma, life cycles, destiny, a turning point", meaning_reversed: "Bad luck, resistance to change, breaking cycles" },
        { name: "justice", number: 11, arcana: "major", suit: nil, meaning_upright: "Justice, fairness, truth, cause and effect, law", meaning_reversed: "Unfairness, lack of accountability, dishonesty" },
        { name: "the hanged man", number: 12, arcana: "major", suit: nil, meaning_upright: "Pause, surrender, letting go, new perspectives", meaning_reversed: "Delays, resistance, stalling, indecision" },
        { name: "death", number: 13, arcana: "major", suit: nil, meaning_upright: "End of cycle, beginnings, change, metamorphosis, transformation", meaning_reversed: "Resistance to change, inability to move on, stagnation" },
        { name: "temperance", number: 14, arcana: "major", suit: nil, meaning_upright: "Balance, moderation, patience, purpose, meaning", meaning_reversed: "Imbalance, excess, self-healing, re-alignment" },
        { name: "the devil", number: 15, arcana: "major", suit: nil, meaning_upright: "Shadow self, attachment, addiction, restriction, sexuality", meaning_reversed: "Releasing limiting beliefs, exploring dark thoughts, detachment" },
        { name: "the tower", number: 16, arcana: "major", suit: nil, meaning_upright: "Sudden change, upheaval, chaos, revelation, awakening", meaning_reversed: "Fear of change, avoiding disaster, delaying the inevitable" },
        { name: "the star", number: 17, arcana: "major", suit: nil, meaning_upright: "Hope, faith, purpose, renewal, spirituality", meaning_reversed: "Lack of faith, despair, self-trust, disconnection" },
        { name: "the moon", number: 18, arcana: "major", suit: nil, meaning_upright: "Illusion, fear, anxiety, subconscious, intuition", meaning_reversed: "Release of fear, repressed emotion, inner confusion" },
        { name: "the sun", number: 19, arcana: "major", suit: nil, meaning_upright: "Positivity, fun, warmth, success, vitality", meaning_reversed: "Inner child, feeling down, overly optimistic" },
        { name: "judgment", number: 20, arcana: "major", suit: nil, meaning_upright: "Judgment, rebirth, inner calling, absolution", meaning_reversed: "Self-doubt, self-judgment, inner critic, ignoring the call" },
        { name: "the world", number: 21, arcana: "major", suit: nil, meaning_upright: "Completion, integration, accomplishment, travel", meaning_reversed: "Seeking personal closure, short-cuts, delays" }
      ]

      # Minor Arcana - Wands (1-10, Page, Knight, Queen, King)
      wands = [
        { name: "ace of wands", number: 1, arcana: "minor", suit: "wands", meaning_upright: "Creation, willpower, inspiration, desire", meaning_reversed: "Lack of energy, lack of passion, boredom" },
        { name: "two of wands", number: 2, arcana: "minor", suit: "wands", meaning_upright: "Planning, making decisions, leaving home", meaning_reversed: "Fear of change, playing it safe, bad planning" },
        { name: "three of wands", number: 3, arcana: "minor", suit: "wands", meaning_upright: "Looking ahead, expansion, rapid growth", meaning_reversed: "Obstacles, delays, frustration" },
        { name: "four of wands", number: 4, arcana: "minor", suit: "wands", meaning_upright: "Community, home, celebration, harmony", meaning_reversed: "Lack of support, transience, instability" },
        { name: "five of wands", number: 5, arcana: "minor", suit: "wands", meaning_upright: "Competition, conflict, diversity", meaning_reversed: "Avoiding conflict, respecting differences" },
        { name: "six of wands", number: 6, arcana: "minor", suit: "wands", meaning_upright: "Victory, success, public recognition", meaning_reversed: "Excess pride, lack of recognition, punishment" },
        { name: "seven of wands", number: 7, arcana: "minor", suit: "wands", meaning_upright: "Challenge, competition, protection", meaning_reversed: "Giving up, overwhelmed, defensiveness" },
        { name: "eight of wands", number: 8, arcana: "minor", suit: "wands", meaning_upright: "Speed, action, air travel, movement", meaning_reversed: "Delays, frustration, resisting change" },
        { name: "nine of wands", number: 9, arcana: "minor", suit: "wands", meaning_upright: "Resilience, courage, persistence", meaning_reversed: "Exhaustion, giving up, overwhelmed" },
        { name: "ten of wands", number: 10, arcana: "minor", suit: "wands", meaning_upright: "Burden, responsibility, hard work", meaning_reversed: "Inability to delegate, overstressed, burned out" },
        { name: "page of wands", number: 11, arcana: "minor", suit: "wands", meaning_upright: "Exploration, excitement, freedom", meaning_reversed: "Lack of direction, procrastination, creating conflict" },
        { name: "knight of wands", number: 12, arcana: "minor", suit: "wands", meaning_upright: "Action, adventure, fearlessness", meaning_reversed: "Anger, impulsiveness, recklessness" },
        { name: "queen of wands", number: 13, arcana: "minor", suit: "wands", meaning_upright: "Courage, determination, joy", meaning_reversed: "Selfishness, jealousy, insecurities" },
        { name: "king of wands", number: 14, arcana: "minor", suit: "wands", meaning_upright: "Natural-born leader, vision, entrepreneur", meaning_reversed: "Impulsiveness, haste, ruthlessness" }
      ]

      # Minor Arcana - Cups (1-10, Page, Knight, Queen, King)
      cups = [
        { name: "ace of cups", number: 1, arcana: "minor", suit: "cups", meaning_upright: "Love, new feelings, emotional awakening", meaning_reversed: "Emotional loss, blocked creativity, emptiness" },
        { name: "two of cups", number: 2, arcana: "minor", suit: "cups", meaning_upright: "Unity, partnership, connection", meaning_reversed: "Disconnection, misalignment, imbalance" },
        { name: "three of cups", number: 3, arcana: "minor", suit: "cups", meaning_upright: "Friendship, community, happiness", meaning_reversed: "Overindulgence, gossip, isolation" },
        { name: "four of cups", number: 4, arcana: "minor", suit: "cups", meaning_upright: "Apathy, contemplation, disconnectedness", meaning_reversed: "Sudden awareness, choosing happiness, acceptance" },
        { name: "five of cups", number: 5, arcana: "minor", suit: "cups", meaning_upright: "Regret, failure, disappointment", meaning_reversed: "Acceptance, moving on, finding peace" },
        { name: "six of cups", number: 6, arcana: "minor", suit: "cups", meaning_upright: "Revisiting the past, childhood memories, innocence", meaning_reversed: "Living in the past, naivete, unrealistic" },
        { name: "seven of cups", number: 7, arcana: "minor", suit: "cups", meaning_upright: "Opportunities, choices, wishful thinking", meaning_reversed: "Lack of purpose, diversion, confusion" },
        { name: "eight of cups", number: 8, arcana: "minor", suit: "cups", meaning_upright: "Walking away, disillusionment, leaving behind", meaning_reversed: "Avoidance, fear of change, fear of loss" },
        { name: "nine of cups", number: 9, arcana: "minor", suit: "cups", meaning_upright: "Contentment, satisfaction, gratitude", meaning_reversed: "Inner happiness, materialism, dissatisfaction" },
        { name: "ten of cups", number: 10, arcana: "minor", suit: "cups", meaning_upright: "Divine love, harmony, alignment", meaning_reversed: "Broken home, domestic disharmony, relationship struggles" },
        { name: "page of cups", number: 11, arcana: "minor", suit: "cups", meaning_upright: "Creative opportunities, curiosity, possibility", meaning_reversed: "Emotional immaturity, insecurity, disappointment" },
        { name: "knight of cups", number: 12, arcana: "minor", suit: "cups", meaning_upright: "Creativity, romance, charm, imagination", meaning_reversed: "Moodiness, disappointment, unrealistic" },
        { name: "queen of cups", number: 13, arcana: "minor", suit: "cups", meaning_upright: "Compassion, calm, comfort", meaning_reversed: "Martyrdom, insecurity, dependence" },
        { name: "king of cups", number: 14, arcana: "minor", suit: "cups", meaning_upright: "Emotional control, balance, compassion", meaning_reversed: "Coldness, moodiness, bad advice" }
      ]

      # Minor Arcana - Swords (1-10, Page, Knight, Queen, King)
      swords = [
        { name: "ace of swords", number: 1, arcana: "minor", suit: "swords", meaning_upright: "Breakthrough, clarity, sharp mind", meaning_reversed: "Confusion, brutality, chaos" },
        { name: "two of swords", number: 2, arcana: "minor", suit: "swords", meaning_upright: "Difficult choices, indecision, stalemate", meaning_reversed: "Lesser of two evils, no win scenarios, confusion" },
        { name: "three of swords", number: 3, arcana: "minor", suit: "swords", meaning_upright: "Heartbreak, emotional pain, sorrow", meaning_reversed: "Recovery, forgiveness, moving on" },
        { name: "four of swords", number: 4, arcana: "minor", suit: "swords", meaning_upright: "Rest, restoration, contemplation", meaning_reversed: "Restlessness, burnout, exhaustion" },
        { name: "five of swords", number: 5, arcana: "minor", suit: "swords", meaning_upright: "Conflict, disagreements, competition", meaning_reversed: "Reconciliation, making amends, compromise" },
        { name: "six of swords", number: 6, arcana: "minor", suit: "swords", meaning_upright: "Transition, change, rite of passage", meaning_reversed: "Stuck in the past, no solution, resistance" },
        { name: "seven of swords", number: 7, arcana: "minor", suit: "swords", meaning_upright: "Deception, trickery, tactics and strategy", meaning_reversed: "Coming clean, rethinking approach, deception" },
        { name: "eight of swords", number: 8, arcana: "minor", suit: "swords", meaning_upright: "Imprisonment, entrapment, self-victimization", meaning_reversed: "Self acceptance, new perspective, freedom" },
        { name: "nine of swords", number: 9, arcana: "minor", suit: "swords", meaning_upright: "Anxiety, hopelessness, trauma", meaning_reversed: "Hope, reaching out, despair" },
        { name: "ten of swords", number: 10, arcana: "minor", suit: "swords", meaning_upright: "Painful endings, deep wounds, betrayal", meaning_reversed: "Recovery, regeneration, resisting an inevitable end" },
        { name: "page of swords", number: 11, arcana: "minor", suit: "swords", meaning_upright: "New ideas, curiosity, thirst for knowledge", meaning_reversed: "Self-expression, all talk and no action, haste" },
        { name: "knight of swords", number: 12, arcana: "minor", suit: "swords", meaning_upright: "Action, impulsiveness, defending beliefs", meaning_reversed: "No direction, disregard for consequences, unpredictability" },
        { name: "queen of swords", number: 13, arcana: "minor", suit: "swords", meaning_upright: "Independent, unbiased judgment, clear boundaries", meaning_reversed: "Harsh judgment, excessive criticism, coldness" },
        { name: "king of swords", number: 14, arcana: "minor", suit: "swords", meaning_upright: "Truth, authority, intellectual power", meaning_reversed: "Manipulation, tyranny, abusing power" }
      ]

      # Minor Arcana - Pentacles (1-10, Page, Knight, Queen, King)
      pentacles = [
        { name: "ace of pentacles", number: 1, arcana: "minor", suit: "pentacles", meaning_upright: "New financial opportunity, prosperity, abundance", meaning_reversed: "Missed opportunity, scarcity, deficiency" },
        { name: "two of pentacles", number: 2, arcana: "minor", suit: "pentacles", meaning_upright: "Balance, prioritization, adaptation", meaning_reversed: "Imbalance, disorganization, overwhelmed" },
        { name: "three of pentacles", number: 3, arcana: "minor", suit: "pentacles", meaning_upright: "Teamwork, collaboration, learning", meaning_reversed: "Lack of teamwork, disorganized, group conflict" },
        { name: "four of pentacles", number: 4, arcana: "minor", suit: "pentacles", meaning_upright: "Saving money, security, conservatism", meaning_reversed: "Generosity, giving, spending" },
        { name: "five of pentacles", number: 5, arcana: "minor", suit: "pentacles", meaning_upright: "Need, poverty, insecurity", meaning_reversed: "Recovery, charity, improvement" },
        { name: "six of pentacles", number: 6, arcana: "minor", suit: "pentacles", meaning_upright: "Giving, receiving, sharing wealth", meaning_reversed: "Strings attached, stinginess, power and domination" },
        { name: "seven of pentacles", number: 7, arcana: "minor", suit: "pentacles", meaning_upright: "Hard work, perseverance, diligence", meaning_reversed: "Work without results, distractions, lack of rewards" },
        { name: "eight of pentacles", number: 8, arcana: "minor", suit: "pentacles", meaning_upright: "Apprenticeship, passion, high standards", meaning_reversed: "Lack of passion, uninspired, empty" },
        { name: "nine of pentacles", number: 9, arcana: "minor", suit: "pentacles", meaning_upright: "Gratitude, luxury, self-sufficiency", meaning_reversed: "Reckless spending, superficial, hampering self-sufficiency" },
        { name: "ten of pentacles", number: 10, arcana: "minor", suit: "pentacles", meaning_upright: "Legacy, roots, family", meaning_reversed: "Family disputes, bankruptcy, debt" },
        { name: "page of pentacles", number: 11, arcana: "minor", suit: "pentacles", meaning_upright: "Ambition, desire, diligence", meaning_reversed: "Lack of progress, procrastination, lack of focus" },
        { name: "knight of pentacles", number: 12, arcana: "minor", suit: "pentacles", meaning_upright: "Hard work, productivity, routine", meaning_reversed: "Self-discipline, boredom, perfectionism" },
        { name: "queen of pentacles", number: 13, arcana: "minor", suit: "pentacles", meaning_upright: "Practicality, creature comforts, security", meaning_reversed: "Self-centeredness, jealousy, smothering" },
        { name: "king of pentacles", number: 14, arcana: "minor", suit: "pentacles", meaning_upright: "Wealth, business, leadership", meaning_reversed: "Greed, indulgence, sensuality" }
      ]

      # Combine all cards
      all_cards = major_arcana + wands + cups + swords + pentacles

      # Create the cards in the database
      all_cards.each do |card|
        TarotCard.create!(
          name: card[:name],
          number: card[:number],
          arcana: card[:arcana],
          suit: card[:suit],
          meaning_upright: card[:meaning_upright],
          meaning_reversed: card[:meaning_reversed]
        )
      end

      puts "created #{TarotCard.count} tarot cards"
    else
      puts "tarot cards already exist, skipping"
    end
  end

  desc "seed spreads"
  task seed_spreads: :environment do
    puts "seeding tarot spreads..."

    # Only seed if no spreads exist
    if Spread.count.zero?
      spreads = [
        {
          name: "three card spread",
          description: "A simple three card spread representing past, present, and future",
          num_cards: 3,
          positions: [
            { name: "past", description: "Influences from the past affecting the situation" },
            { name: "present", description: "Current energy and circumstances" },
            { name: "future", description: "Potential outcome or future development" }
          ]
        },
        {
          name: "celtic cross",
          description: "A comprehensive 10-card spread for deep insights into a situation",
          num_cards: 10,
          positions: [
            { name: "present", description: "The present situation or influence" },
            { name: "challenge", description: "The immediate challenge or obstacle" },
            { name: "foundation", description: "The basis of the situation" },
            { name: "past", description: "Recent past events or influences" },
            { name: "crown", description: "Potential outcome or goal" },
            { name: "future", description: "The immediate future" },
            { name: "self", description: "Your attitude or position" },
            { name: "environment", description: "External influences" },
            { name: "hopes/fears", description: "Your hopes and/or fears" },
            { name: "outcome", description: "The final outcome" }
          ]
        },
        {
          name: "relationship spread",
          description: "A 5-card spread to gain insight into a relationship",
          num_cards: 5,
          positions: [
            { name: "self", description: "How you view yourself in the relationship" },
            { name: "partner", description: "How you view your partner" },
            { name: "relationship", description: "The current state of the relationship" },
            { name: "challenge", description: "The main challenge or obstacle" },
            { name: "outcome", description: "Potential direction of the relationship" }
          ]
        }
      ]

      # Create the spreads in the database
      spreads.each do |spread|
        Spread.create!(
          name: spread[:name],
          description: spread[:description],
          num_cards: spread[:num_cards],
          positions: spread[:positions]
        )
      end

      puts "created #{Spread.count} tarot spreads"
    else
      puts "tarot spreads already exist, skipping"
    end
  end

  desc "seed all tarot data"
  task seed_all: [ :seed_cards, :seed_spreads ] do
    puts "all tarot data seeded successfully"
  end
end
