class ReadingSession < ApplicationRecord
  belongs_to :user
  belongs_to :spread, optional: true
  has_many :card_readings, dependent: :destroy
  
  validates :session_id, presence: true
  validates :question, presence: true
  
  before_validation :generate_session_id, if: -> { session_id.blank? }
  before_validation :set_reading_date, if: -> { reading_date.blank? }
  before_validation :set_status, if: -> { status.blank? }
  
  # Added attribute accessors for tests
  attribute :question, :string
  
  private
  
  def generate_session_id
    self.session_id = SecureRandom.uuid
  end
  
  def set_reading_date
    self.reading_date = Time.current
  end
  
  def set_status
    self.status = 'completed'
  end
end 