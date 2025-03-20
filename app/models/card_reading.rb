class CardReading < ApplicationRecord
  belongs_to :user
  belongs_to :card
  belongs_to :spread, optional: true
  belongs_to :reading, optional: true

  validates :position, presence: true
  validates :is_reversed, inclusion: { in: [ true, false ] }

  before_create :set_reading_date

  private

  def set_reading_date
    self.reading_date ||= Time.current
  end
end
