class TarotCard < ApplicationRecord
  has_one_attached :image
  has_many :card_readings
  has_many :users, through: :card_readings

  validates :name, presence: true, uniqueness: true
  validates :arcana, presence: true
  validates :description, presence: true
  validates :rank, presence: true, if: :major_arcana?
  validates :suit, presence: true, if: :minor_arcana?

  def major_arcana?
    arcana == "major"
  end

  def minor_arcana?
    arcana == "minor"
  end
end
