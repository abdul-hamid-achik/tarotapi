class ReadingSession < ApplicationRecord
  # This is a placeholder for the ReadingSession model to support the tests
  belongs_to :user, optional: true
  has_many :card_readings, dependent: :destroy
  
  validates :session_id, presence: true
  
  before_validation :generate_session_id, if: -> { session_id.blank? }
  before_validation :set_reading_date, if: -> { reading_date.blank? }
  before_validation :set_status, if: -> { status.blank? }
  
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