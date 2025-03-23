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
  attribute :reading_date, :datetime

  # Add methods to handle user_id
  def user_id=(id)
    self.user = User.find(id) if id.present?
  end

  def user_id
    user&.id
  end

  # Add methods to handle spread_id
  def spread_id=(id)
    self.spread = Spread.find(id) if id.present?
  end

  def spread_id
    spread&.id
  end

  private

  def set_reading_date
    self.reading_date ||= Time.current
  end
end
