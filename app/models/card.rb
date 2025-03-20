class Card < ApplicationRecord
  has_one_attached :image
  has_many :card_readings
  has_many :users, through: :card_readings
  has_many :readings, through: :card_readings

  validates :name, presence: true, uniqueness: true
  validates :arcana, presence: true
  validates :description, presence: true
  validates :rank, presence: true, if: :major_arcana?
  validates :suit, presence: true, if: :minor_arcana?

  # Case insensitive comparisons for arcana type
  def major_arcana?
    arcana.to_s.downcase == "major"
  end

  def minor_arcana?
    arcana.to_s.downcase == "minor"
  end
  
  # Attach an image from the file system based on the image_url field
  def attach_image_from_file_system
    return unless image_url.present? && !image.attached?
    
    # Strip leading slash if present
    path = image_url.start_with?('/') ? image_url[1..-1] : image_url
    
    # Check seed_data directory first
    seed_path = Rails.root.join('db', 'seed_data', path)
    public_path = Rails.root.join('public', path)
    
    # Find the image in one of the possible locations
    file_path = if File.exist?(seed_path)
                  seed_path
                elsif File.exist?(public_path)
                  public_path
                else
                  # Check for images in cards directory
                  card_name = File.basename(path)
                  alt_path = Rails.root.join('db', 'seed_data', 'cards', card_name)
                  alt_path if File.exist?(alt_path)
                end
    
    # If we found a file, attach it
    if file_path && File.exist?(file_path)
      image.attach(io: File.open(file_path), filename: File.basename(file_path))
      return true
    end
    
    # Log if we couldn't find the file
    Rails.logger.warn("Could not find image file for #{name} at #{image_url}")
    false
  end
end 