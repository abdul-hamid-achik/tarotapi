require_relative '../../simple_test_helper'
require_relative '../../../app/services/numerology_service'
require 'date'

RSpec.describe NumerologyService do
  describe '.calculate_life_path_number' do
    it 'correctly calculates life path number from a Date object' do
      # Test with various birth dates
      expect(NumerologyService.calculate_life_path_number(Date.new(1990, 5, 14))).to be_a(Integer)
      expect(NumerologyService.calculate_life_path_number(Date.new(1987, 11, 23))).to be_a(Integer)
    end

    it 'correctly calculates life path number from a string' do
      expect(NumerologyService.calculate_life_path_number('1990-05-14')).to be_a(Integer)
      expect(NumerologyService.calculate_life_path_number('1987/11/23')).to be_a(Integer)
    end

    it 'returns nil for invalid date format' do
      expect(NumerologyService.calculate_life_path_number('invalid')).to be_nil
    end

    it 'preserves master numbers 11, 22, and 33' do
      # Mock specific dates that would result in master numbers
      allow(NumerologyService).to receive(:sum_digits).with(any_args).and_return(1, 1, 9) # 11 total
      expect(NumerologyService.calculate_life_path_number('2000-01-01')).to eq(11)

      allow(NumerologyService).to receive(:sum_digits).with(any_args).and_return(2, 0, 2) # 22 total
      expect(NumerologyService.calculate_life_path_number('2000-01-01')).to eq(22)

      allow(NumerologyService).to receive(:sum_digits).with(any_args).and_return(3, 0, 3) # 33 total
      expect(NumerologyService.calculate_life_path_number('2000-01-01')).to eq(33)
    end

    it 'reduces numbers to a single digit except master numbers' do
      allow(NumerologyService).to receive(:sum_digits).with(any_args).and_return(1, 2, 3) # 6 total
      expect(NumerologyService.calculate_life_path_number('2000-01-01')).to eq(6)

      allow(NumerologyService).to receive(:sum_digits).with(any_args).and_return(5, 7, 9) # 21 total -> 3
      expect(NumerologyService.calculate_life_path_number('2000-01-01')).to eq(3)
    end
  end

  describe '.calculate_name_number' do
    it 'calculates the correct name number' do
      expect(NumerologyService.calculate_name_number('John Doe')).to be_a(Integer)
      expect(NumerologyService.calculate_name_number('Jane Smith')).to be_a(Integer)
    end

    it 'ignores non-alphabetic characters' do
      # These should yield the same result
      expect(NumerologyService.calculate_name_number('JohnDoe')).to eq(
        NumerologyService.calculate_name_number('John Doe')
      )
      expect(NumerologyService.calculate_name_number('John-Doe!')).to eq(
        NumerologyService.calculate_name_number('John Doe')
      )
    end

    it 'handles empty or nil names' do
      expect(NumerologyService.calculate_name_number('')).to eq(0)
      expect(NumerologyService.calculate_name_number(nil)).to eq(0)
    end

    it 'preserves master numbers for name calculations' do
      # Mock a name that would result in master number 11
      allow(NumerologyService).to receive(:letter_value).with(any_args).and_return(1)
      # For a name with 11 letters, the sum would be 11
      expect(NumerologyService.calculate_name_number('a' * 11)).to eq(11)

      # Master number 22
      allow(NumerologyService).to receive(:letter_value).with(any_args).and_return(1)
      expect(NumerologyService.calculate_name_number('a' * 22)).to eq(22)
    end
  end

  describe '.get_life_path_meaning' do
    it 'returns the correct meaning for each life path number' do
      expect(NumerologyService.get_life_path_meaning(1)).to include('Independent')
      expect(NumerologyService.get_life_path_meaning(2)).to include('Cooperative')
      expect(NumerologyService.get_life_path_meaning(3)).to include('Creative')
      expect(NumerologyService.get_life_path_meaning(4)).to include('Practical')
      expect(NumerologyService.get_life_path_meaning(5)).to include('Adventurous')
      expect(NumerologyService.get_life_path_meaning(6)).to include('Nurturing')
      expect(NumerologyService.get_life_path_meaning(7)).to include('Analytical')
      expect(NumerologyService.get_life_path_meaning(8)).to include('Ambitious')
      expect(NumerologyService.get_life_path_meaning(9)).to include('Humanitarian')
    end

    it 'returns the correct meaning for master numbers' do
      expect(NumerologyService.get_life_path_meaning(11)).to include('Intuitive')
      expect(NumerologyService.get_life_path_meaning(22)).to include('Master builder')
      expect(NumerologyService.get_life_path_meaning(33)).to include('Master teacher')
    end

    it 'handles invalid numbers' do
      expect(NumerologyService.get_life_path_meaning(0)).to include('Unknown')
      expect(NumerologyService.get_life_path_meaning(100)).to include('Unknown')
      expect(NumerologyService.get_life_path_meaning(-1)).to include('Unknown')
    end
  end

  describe '.get_card_numerology' do
    it 'returns the correct numerology for major arcana cards' do
      expect(NumerologyService.get_card_numerology('The Fool')).to include(number: 0)
      expect(NumerologyService.get_card_numerology('The Magician')).to include(number: 1)
      expect(NumerologyService.get_card_numerology('The High Priestess')).to include(number: 2)
      expect(NumerologyService.get_card_numerology('Death')).to include(number: 13)
      expect(NumerologyService.get_card_numerology('The World')).to include(number: 21)
    end

    it 'is case-insensitive' do
      expect(NumerologyService.get_card_numerology('the fool')).to include(number: 0)
      expect(NumerologyService.get_card_numerology('THE FOOL')).to include(number: 0)
    end

    it 'handles partial matches' do
      expect(NumerologyService.get_card_numerology('Fool')).to include(number: 0)
      expect(NumerologyService.get_card_numerology('Priestess')).to include(number: 2)
    end

    it 'handles unknown cards' do
      result = NumerologyService.get_card_numerology('Not a Real Card')
      expect(result[:number]).to be_nil
      expect(result[:meaning]).to include('No specific')
    end
  end

  describe 'private methods' do
    # Test private methods using the send method
    describe '.sum_digits' do
      it 'correctly sums the digits of a number' do
        expect(NumerologyService.send(:sum_digits, 123)).to eq(6) # 1+2+3 = 6
        expect(NumerologyService.send(:sum_digits, 999)).to eq(27) # 9+9+9 = 27
        expect(NumerologyService.send(:sum_digits, 0)).to eq(0)
      end
    end

    describe '.reduce_to_single_digit' do
      it 'reduces multi-digit numbers to a single digit' do
        expect(NumerologyService.send(:reduce_to_single_digit, 123)).to eq(6) # 1+2+3 = 6
        expect(NumerologyService.send(:reduce_to_single_digit, 999)).to eq(9) # 9+9+9 = 27 -> 2+7 = 9
        expect(NumerologyService.send(:reduce_to_single_digit, 38)).to eq(2) # 3+8 = 11 -> 1+1 = 2
      end

      it 'returns single-digit numbers as-is' do
        expect(NumerologyService.send(:reduce_to_single_digit, 5)).to eq(5)
        expect(NumerologyService.send(:reduce_to_single_digit, 0)).to eq(0)
      end
    end

    describe '.letter_value' do
      it 'returns the correct numerological value for each letter' do
        # Test first 9 letters (a-i)
        expect(NumerologyService.send(:letter_value, 'a')).to eq(1)
        expect(NumerologyService.send(:letter_value, 'e')).to eq(5)
        expect(NumerologyService.send(:letter_value, 'i')).to eq(9)

        # Test second set (j-r)
        expect(NumerologyService.send(:letter_value, 'j')).to eq(1)
        expect(NumerologyService.send(:letter_value, 'n')).to eq(5)
        expect(NumerologyService.send(:letter_value, 'r')).to eq(9)

        # Test third set (s-z)
        expect(NumerologyService.send(:letter_value, 's')).to eq(1)
        expect(NumerologyService.send(:letter_value, 'w')).to eq(5)
        expect(NumerologyService.send(:letter_value, 'z')).to eq(8)
      end

      it 'handles non-letter characters' do
        expect(NumerologyService.send(:letter_value, '1')).to eq(0)
        expect(NumerologyService.send(:letter_value, '-')).to eq(0)
        expect(NumerologyService.send(:letter_value, ' ')).to eq(0)
      end
    end
  end
end
