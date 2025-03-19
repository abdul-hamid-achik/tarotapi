require 'rails_helper'

RSpec.describe ReadingSession, type: :model do
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
    describe '#set_reading_date' do
      it 'sets reading_date before validation if not present' do
        freeze_time = Time.current
        allow(Time).to receive(:current).and_return(freeze_time)
        
        session = build(:reading_session, reading_date: nil)
        session.valid?
        
        expect(session.reading_date).to eq(freeze_time)
      end
      
      it 'does not override reading_date if already present' do
        custom_date = 3.days.ago
        session = build(:reading_session, reading_date: custom_date)
        session.valid?
        
        expect(session.reading_date).to eq(custom_date)
      end
    end
    
    describe '#set_default_status' do
      it 'sets status to "completed" if not present' do
        session = build(:reading_session, status: nil)
        session.valid?
        
        expect(session.status).to eq('completed')
      end
      
      it 'does not override status if already present' do
        session = build(:reading_session, status: 'pending')
        session.valid?
        
        expect(session.status).to eq('pending')
      end
    end
    
    describe '#set_session_id' do
      it 'generates a session_id if not present' do
        session = build(:reading_session, session_id: nil)
        session.valid?
        
        expect(session.session_id).not_to be_nil
      end
      
      it 'does not override session_id if already present' do
        custom_id = 'custom-session-id'
        session = build(:reading_session, session_id: custom_id)
        session.valid?
        
        expect(session.session_id).to eq(custom_id)
      end
    end
  end

  describe 'factory' do
    it 'has a valid factory' do
      expect(build(:reading_session)).to be_valid
    end
    
    it 'has a valid factory with card readings' do
      session = create(:reading_session, :with_card_readings)
      expect(session).to be_valid
      expect(session.card_readings).not_to be_empty
    end
  end
end 