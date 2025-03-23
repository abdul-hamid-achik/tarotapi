class CardReading < ApplicationRecord
  belongs_to :user
  belongs_to :card
  belongs_to :spread, optional: true
  belongs_to :reading, optional: true
  belongs_to :reading_session, optional: true

  # Properly alias tarot_card to card with alias_method
  alias_method :tarot_card, :card
  alias_method :tarot_card=, :card=

  validates :position, presence: true
  validates :is_reversed, inclusion: { in: [ true, false ] }

  before_create :set_reading_date

  # Add these attributes for the tests if they don't exist on the model
  attribute :is_reversed, :boolean, default: false

  private

  def set_reading_date
    self.reading_date ||= Time.current
  end
end
