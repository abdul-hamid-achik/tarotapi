require 'rails_helper'

RSpec.describe InterpretationService do
  let(:user) { create(:user) }
  let(:spread) { create(:spread, name: "Celtic Cross") }
  let(:reading) { create(:reading, user: user, spread: spread, question: "What does my future hold?") }
  let(:card1) { create(:card, name: "The Fool", arcana: "major", rank: 0, suit: nil) }
  let(:card2) { create(:card, name: "The Tower", arcana: "major", rank: 16, suit: nil) }

  let(:card_reading1) do
    create(:card_reading,
      card: card1,
      reading: reading,
      position: 1,
      is_reversed: false,
      spread_position: { "name" => "Present", "description" => "Current situation" }
    )
  end

  let(:card_reading2) do
    create(:card_reading,
      card: card2,
      reading: reading,
      position: 2,
      is_reversed: true,
      spread_position: { "name" => "Challenge", "description" => "Current obstacle" }
    )
  end

  let(:readings) { [ card_reading1, card_reading2 ] }
  let(:birth_date) { Date.new(1990, 1, 15) }
  let(:name) { "Jane Doe" }

  let(:llm_service_instance) { instance_double(LlmService) }

  subject(:service) do
    described_class.new(
      user: user,
      spread: spread,
      reading: reading,
      birth_date: birth_date,
      name: name
    )
  end

  before do
    allow(LlmService).to receive(:instance).and_return(llm_service_instance)
    allow(llm_service_instance).to receive(:set_user)

    # Mock the numerology service
    allow(NumerologyService).to receive(:calculate_life_path_number).and_return(7)
    allow(NumerologyService).to receive(:calculate_name_number).and_return(5)

    # Mock the symbolism service
    allow(SymbolismService).to receive(:identify_symbols_in_card).and_return([ "sun", "mountain" ])
  end

  describe '#initialize' do
    it 'sets user, spread, reading, birth_date and name attributes' do
      expect(service.user).to eq(user)
      expect(service.spread).to eq(spread)
      expect(service.reading).to eq(reading)
      expect(service.birth_date).to eq(birth_date)
      expect(service.name).to eq(name)
    end

    it 'initializes LlmService with the user' do
      expect(LlmService).to have_received(:instance)
      expect(llm_service_instance).to have_received(:set_user).with(user)
    end
  end

  describe '#interpret' do
    it 'prepares context and calls LlmService#interpret_reading' do
      expect(llm_service_instance).to receive(:interpret_reading) do |params|
        # Verify cards
        expect(params[:cards].size).to eq(2)
        expect(params[:cards][0][:name]).to eq("The Fool")
        expect(params[:cards][1][:name]).to eq("The Tower")

        # Verify positions
        expect(params[:positions].size).to eq(2)
        expect(params[:positions][0][:name]).to eq("Present")
        expect(params[:positions][1][:name]).to eq("Challenge")

        # Verify spread name
        expect(params[:spread_name]).to eq("Celtic Cross")

        # Verify is_reversed
        expect(params[:is_reversed]).to eq([ true ])

        # Verify question
        expect(params[:question]).to eq("What does my future hold?")

        # Verify numerological context
        expect(params[:numerological_context][:life_path_number]).to eq(7)
        expect(params[:numerological_context][:name_number]).to eq(5)

        # Verify symbolism context
        expect(params[:symbolism_context][:cards]).to eq([ "The Fool", "The Tower" ])
        expect(params[:symbolism_context][:symbolism]["The Fool"]).to eq([ "sun", "mountain" ])
        expect(params[:symbolism_context][:symbolism]["The Tower"]).to eq([ "sun", "mountain" ])

        # Return mock interpretation
        "This is your tarot reading interpretation."
      end

      result = service.interpret(readings)
      expect(result).to eq("This is your tarot reading interpretation.")
    end

    context 'without spread in reading' do
      let(:reading) { create(:reading, user: user, spread: nil, question: "What does my future hold?") }

      it 'uses "Custom Spread" as the spread name' do
        expect(llm_service_instance).to receive(:interpret_reading) do |params|
          expect(params[:spread_name]).to eq("Custom Spread")
          "Custom spread interpretation."
        end

        result = service.interpret(readings)
        expect(result).to eq("Custom spread interpretation.")
      end
    end

    context 'without position names in card readings' do
      let(:card_reading1) do
        create(:card_reading,
          card: card1,
          reading: reading,
          position: 1,
          is_reversed: false,
          spread_position: nil
        )
      end

      it 'generates default position names' do
        expect(llm_service_instance).to receive(:interpret_reading) do |params|
          expect(params[:positions][0][:name]).to eq("Position 1")
          expect(params[:positions][0][:description]).to eq("Card position 1")
          "Position-less interpretation."
        end

        result = service.interpret(readings)
        expect(result).to eq("Position-less interpretation.")
      end
    end
  end

  describe '#interpret_streaming' do
    it 'prepares context and calls LlmService#interpret_reading_streaming' do
      # Mock streaming response
      chunks = [ "This ", "is ", "your ", "tarot ", "reading." ]
      collected_chunks = []

      expect(llm_service_instance).to receive(:interpret_reading_streaming) do |params, &block|
        # Verify same parameters as in non-streaming version
        expect(params[:cards].size).to eq(2)
        expect(params[:positions].size).to eq(2)
        expect(params[:spread_name]).to eq("Celtic Cross")

        # Simulate streaming by yielding chunks
        chunks.each do |chunk|
          block.call(chunk)
        end
      end

      # Call the method with a block to collect chunks
      service.interpret_streaming(readings) do |chunk|
        collected_chunks << chunk
      end

      # Verify all chunks were received
      expect(collected_chunks).to eq(chunks)
    end
  end

  describe '#prepare_context' do
    it 'builds complete context from readings and additional data' do
      # Call the private method directly
      context = service.send(:prepare_context, readings)

      # Verify all expected context elements
      expect(context[:cards].size).to eq(2)
      expect(context[:positions].size).to eq(2)
      expect(context[:spread_name]).to eq("Celtic Cross")
      expect(context[:is_reversed]).to eq([ true ])
      expect(context[:question]).to eq("What does my future hold?")

      # Verify numerological context
      expect(context[:numerological_context][:life_path_number]).to eq(7)
      expect(context[:numerological_context][:name_number]).to eq(5)
      expect(context[:numerological_context][:name]).to eq("Jane Doe")
      expect(context[:numerological_context][:birth_date]).to eq(birth_date.to_s)

      # Verify symbolism context
      expect(context[:symbolism_context][:cards]).to eq([ "The Fool", "The Tower" ])
      expect(context[:symbolism_context][:symbolism]["The Fool"]).to eq([ "sun", "mountain" ])
      expect(context[:symbolism_context][:symbolism]["The Tower"]).to eq([ "sun", "mountain" ])
    end

    context 'without birth date' do
      subject(:service) do
        described_class.new(
          user: user,
          spread: spread,
          reading: reading,
          birth_date: nil,
          name: name
        )
      end

      it 'sets numerological_context to nil' do
        context = service.send(:prepare_context, readings)
        expect(context[:numerological_context]).to be_nil
      end
    end

    context 'without name but with birth date' do
      subject(:service) do
        described_class.new(
          user: user,
          spread: spread,
          reading: reading,
          birth_date: birth_date,
          name: nil
        )
      end

      it 'includes life_path_number but not name_number' do
        context = service.send(:prepare_context, readings)
        expect(context[:numerological_context][:life_path_number]).to eq(7)
        expect(context[:numerological_context]).not_to have_key(:name_number)
        expect(context[:numerological_context]).not_to have_key(:name)
      end
    end
  end
end
