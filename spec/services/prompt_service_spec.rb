require 'rails_helper'

RSpec.describe PromptService do
  describe '.get_prompt' do
    context 'with a valid prompt type' do
      it 'returns the correct prompt for tarot_reading' do
        context = {
          question: "Will I find a new job soon?",
          cards: [
            { name: "The Fool", position: "Present" },
            { name: "The Tower", position: "Challenge" }
          ],
          spread_name: "Simple Spread"
        }

        prompt = described_class.get_prompt(PromptService::PROMPT_TYPES[:tarot_reading], context)

        expect(prompt).to be_a(Hash)
        expect(prompt[:system]).to be_a(String)
        expect(prompt[:user]).to be_a(String)
        expect(prompt[:user]).to include("Will I find a new job soon?")
        expect(prompt[:user]).to include("The Fool")
        expect(prompt[:user]).to include("The Tower")
        expect(prompt[:user]).to include("Simple Spread")
      end

      it 'returns the correct prompt for card_meaning' do
        context = {
          card_name: "The High Priestess",
          reading_context: "career"
        }

        prompt = described_class.get_prompt(PromptService::PROMPT_TYPES[:card_meaning], context)

        expect(prompt).to be_a(Hash)
        expect(prompt[:system]).to be_a(String)
        expect(prompt[:user]).to be_a(String)
        expect(prompt[:user]).to include("The High Priestess")
        expect(prompt[:user]).to include("career")
      end

      it 'returns the correct prompt for spread_explanation' do
        context = {
          spread_name: "Celtic Cross",
          positions: {
            "1" => "The Present",
            "2" => "The Challenge"
          }
        }

        prompt = described_class.get_prompt(PromptService::PROMPT_TYPES[:spread_explanation], context)

        expect(prompt).to be_a(Hash)
        expect(prompt[:system]).to be_a(String)
        expect(prompt[:user]).to be_a(String)
        expect(prompt[:user]).to include("Celtic Cross")
        expect(prompt[:user]).to include("The Present")
        expect(prompt[:user]).to include("The Challenge")
      end

      it 'returns the correct prompt for astrological_influence' do
        context = {
          zodiac_sign: "Taurus",
          moon_phase: "Full Moon",
          cards: [
            { name: "The Sun", position: "Present" }
          ]
        }

        prompt = described_class.get_prompt(PromptService::PROMPT_TYPES[:astrological_influence], context)

        expect(prompt).to be_a(Hash)
        expect(prompt[:system]).to be_a(String)
        expect(prompt[:user]).to be_a(String)
        expect(prompt[:user]).to include("Taurus")
        expect(prompt[:user]).to include("Full Moon")
        expect(prompt[:user]).to include("The Sun")
      end
    end

    context 'with an invalid prompt type' do
      it 'raises an ArgumentError' do
        expect {
          described_class.get_prompt("invalid_type", {})
        }.to raise_error(ArgumentError, "Unknown prompt type: invalid_type")
      end
    end
  end

  describe 'individual prompt methods' do
    let(:context) do
      {
        question: "Will I find love?",
        cards: [
          { name: "The Lovers", position: "Present", is_reversed: false, description: "Harmony and union" },
          { name: "Two of Cups", position: "Future", is_reversed: true, description: "Partnership and attraction" }
        ],
        spread_name: "Love Spread",
        zodiac_sign: "Libra",
        moon_phase: "New Moon",
        numerology_number: 7
      }
    end

    PromptService::PROMPT_TYPES.each_value do |prompt_type|
      it "returns a valid prompt structure for #{prompt_type}" do
        prompt = described_class.get_prompt(prompt_type, context)

        expect(prompt).to be_a(Hash)
        expect(prompt).to have_key(:system)
        expect(prompt).to have_key(:user)
        expect(prompt[:system]).to be_a(String)
        expect(prompt[:user]).to be_a(String)
        expect(prompt[:system].length).to be > 0
        expect(prompt[:user].length).to be > 0
      end
    end
  end

  describe 'building user prompts' do
    let(:cards) do
      [
        { name: "The Fool", position: "Past", is_reversed: false, description: "New beginnings" },
        { name: "The Magician", position: "Present", is_reversed: true, description: "Manifestation" }
      ]
    end

    it 'includes card positions and reversal status for tarot reading' do
      context = {
        question: "What should I focus on?",
        cards: cards,
        spread_name: "Simple Spread"
      }

      prompt = described_class.get_prompt(PromptService::PROMPT_TYPES[:tarot_reading], context)

      # Check that the prompt includes position information
      expect(prompt[:user]).to include("Past")
      expect(prompt[:user]).to include("Present")

      # Check that reversal status is indicated
      expect(prompt[:user]).to include("The Fool")
      expect(prompt[:user]).to include("The Magician (Reversed)")
    end

    it 'includes astrological information when provided' do
      context = {
        question: "What should I focus on?",
        cards: cards,
        spread_name: "Simple Spread",
        zodiac_sign: "Cancer",
        moon_phase: "Waning Gibbous"
      }

      prompt = described_class.get_prompt(PromptService::PROMPT_TYPES[:tarot_reading], context)

      expect(prompt[:user]).to include("Cancer")
      expect(prompt[:user]).to include("Waning Gibbous")
    end
  end
end
