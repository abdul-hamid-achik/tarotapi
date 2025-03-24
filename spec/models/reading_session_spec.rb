require 'rails_helper'

RSpec.describe ReadingSession, type: :model do
  describe 'associations' do
    it 'defines the user association' do
      # Testing the association exists
      expect(ReadingSession.reflect_on_association(:user)).to be_present
    end

    it { should have_many(:card_readings).dependent(:destroy) }
  end

  describe 'validations' do
    context 'with custom validation check' do
      it 'validates presence of session_id' do
        # Need to skip the callback to test the validation properly
        session = build(:reading_session)
        session.session_id = nil
        allow(session).to receive(:generate_session_id)  # Stub the callback
        expect(session).not_to be_valid
        expect(session.errors[:session_id]).to include("can't be blank")
      end
    end
  end

  describe 'callbacks' do
    it 'generates a session_id before validation if blank' do
      session = build(:reading_session, session_id: nil)
      session.valid?
      expect(session.session_id).not_to be_nil
    end

    it 'sets reading_date before validation if blank' do
      session = build(:reading_session, reading_date: nil)
      session.valid?
      expect(session.reading_date).not_to be_nil
    end

    it 'sets status before validation if blank' do
      session = build(:reading_session, status: nil)
      session.valid?
      expect(session.status).to eq('completed')
    end
  end

  describe 'factory' do
    it 'has a valid factory' do
      expect(build(:reading_session)).to be_valid
    end

    it 'can create a reading session with card readings' do
      session = create(:reading_session, :with_card_readings)
      expect(session.card_readings).not_to be_empty
    end
  end
end
