require 'rails_helper'

RSpec.describe Reading, type: :model do
  describe 'associations' do
    it { should belong_to(:user) }
    it { should belong_to(:spread).optional }
    it { should have_many(:card_readings).dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_presence_of(:reading_date) }
    it { should validate_presence_of(:question) }
    it { should validate_inclusion_of(:status).in_array(%w[pending completed]) }
    it { should validate_presence_of(:session_id) }
    it { should validate_uniqueness_of(:session_id) }
  end

  describe 'callbacks' do
    context 'before validation on create' do
      describe '#set_reading_date' do
        it 'sets reading_date to current time if not present' do
          reading = build(:reading, reading_date: nil)
          expect { reading.valid? }.to change { reading.reading_date }.from(nil)
        end

        it 'does not change reading_date if already set' do
          custom_date = 1.day.ago
          reading = build(:reading, reading_date: custom_date)
          expect { reading.valid? }.not_to change { reading.reading_date }
        end
      end

      describe '#set_default_status' do
        it 'sets status to "completed" if not present' do
          reading = build(:reading, status: nil)
          expect { reading.valid? }.to change { reading.status }.from(nil).to("completed")
        end

        it 'does not change status if already set' do
          reading = build(:reading, status: "pending")
          expect { reading.valid? }.not_to change { reading.status }
        end
      end

      describe '#set_session_id' do
        it 'sets session_id if not present' do
          allow(SecureRandom).to receive(:uuid).and_return('test-uuid')
          reading = build(:reading, session_id: nil)

          expect { reading.valid? }.to change { reading.session_id }.from(nil)
        end

        it 'does not change session_id if already set' do
          custom_session_id = 'custom-session-id'
          reading = build(:reading, session_id: custom_session_id)
          expect { reading.valid? }.not_to change { reading.session_id }
        end

        context 'in test environment' do
          it 'creates a deterministic UUID if id is present' do
            reading = build(:reading, id: 123, session_id: nil)
            reading.valid?
            expect(reading.session_id).to eq("1231111-1111-1111-111111111111")
          end
        end
      end

      describe '#generate_name' do
        it 'generates a name from question, spread, and date if name not present' do
          Timecop.freeze(Time.local(2023, 1, 15, 12, 0, 0)) do
            spread = create(:spread, name: "Celtic Cross")
            reading = build(:reading,
              question: "What does my future hold?",
              spread: spread,
              astrological_context: { "zodiac_sign" => "Taurus", "moon_phase" => "Waxing" },
              name: nil
            )

            allow(Time).to receive(:now).and_return(Time.local(2023, 1, 15, 12, 0, 0))
            allow(SecureRandom).to receive(:hex).and_return('abcd1234')

            reading.valid?
            expect(reading.name).to include("What does my future hold")
            expect(reading.name).to include("using Celtic Cross spread")
            expect(reading.name).to include("during Taurus")
            expect(reading.name).to include("with Waxing moon")
            expect(reading.name).to include("on Jan 15, 2023")
          end
        end

        it 'does not change name if already set' do
          custom_name = "My Special Reading"
          reading = build(:reading, name: custom_name)
          expect { reading.valid? }.not_to change { reading.name }
        end

        it 'generates a unique name in test environment' do
          reading = build(:reading, name: nil)
          reading.valid?
          expect(reading.name).to start_with("Test Reading")
        end

        it 'truncates names longer than 100 characters' do
          very_long_question = "A" * 200
          reading = build(:reading, question: very_long_question, name: nil)
          reading.valid?
          expect(reading.name.length).to be <= 100
        end
      end
    end
  end

  describe 'factory' do
    it 'has a valid factory' do
      expect(build(:reading)).to be_valid
    end

    it 'has a valid factory with :pending trait' do
      expect(build(:reading, :pending)).to be_valid
      expect(build(:reading, :pending).status).to eq('pending')
    end

    it 'has a valid factory with :without_spread trait' do
      expect(build(:reading, :without_spread)).to be_valid
      expect(build(:reading, :without_spread).spread).to be_nil
    end

    it 'has a valid factory with :with_custom_name trait' do
      expect(build(:reading, :with_custom_name)).to be_valid
      expect(build(:reading, :with_custom_name).name).to eq('Custom Reading Name')
    end

    it 'has a valid factory with :with_card_readings trait' do
      reading = create(:reading, :with_card_readings)
      expect(reading).to be_valid
      expect(reading.card_readings.size).to eq(3)
    end
  end
end
