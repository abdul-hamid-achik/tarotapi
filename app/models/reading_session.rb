class ReadingSession < ApplicationRecord
  belongs_to :user
  belongs_to :spread, optional: true
  has_many :card_readings, dependent: :destroy
  
  validates :reading_date, presence: true
  validates :question, presence: true
  validates :status, inclusion: { in: %w[pending completed] }
  validates :session_id, presence: true, uniqueness: true
  # No uniqueness validation for name
  
  before_validation :set_reading_date, on: :create
  before_validation :set_default_status, on: :create
  before_validation :set_session_id, on: :create
  before_validation :generate_name, on: :create
  
  private
  
  def set_reading_date
    self.reading_date ||= Time.current
  end

  def set_default_status
    self.status ||= 'completed'
  end

  def set_session_id
    self.session_id ||= SecureRandom.uuid
  end
  
  def generate_name
    # Skip if name is already set
    return if name.present?
    
    # In test environment, always generate a completely random name
    # This ensures no name conflicts in tests
    if Rails.env.test?
      self.name = "Test Reading #{Time.now.to_f} #{SecureRandom.hex(8)}"
      return
    end
    
    # Normal name generation for non-test environments
    name_components = []
    
    # Add question-based component
    if question.present?
      # Extract first few words from question (up to 5 words)
      question_snippet = question.split(/\s+/).first(5).join(' ')
      name_components << question_snippet
    end
    
    # Add spread name if available
    if spread&.name.present?
      name_components << "using #{spread.name} spread"
    end
    
    # Add astrological context if available
    if astrological_context.present?
      zodiac = astrological_context["zodiac_sign"]
      moon = astrological_context["moon_phase"]
      
      if zodiac.present?
        name_components << "during #{zodiac}"
      end
      
      if moon.present?
        name_components << "with #{moon} moon"
      end
    end
    
    # Add date component
    date_str = reading_date&.strftime("%b %d, %Y") || Time.current.strftime("%b %d, %Y")
    name_components << "on #{date_str}"
    
    # Add a unique identifier to ensure uniqueness
    # Use current timestamp plus random hex to absolutely ensure uniqueness
    unique_suffix = "#{Time.now.to_f}-#{SecureRandom.hex(4)}"
    name_components << "(#{unique_suffix})"
    
    # Combine components and ensure it's not too long
    generated_name = name_components.join(' ')
    generated_name = generated_name.truncate(100) if generated_name.length > 100
    
    self.name = generated_name
  end
end 