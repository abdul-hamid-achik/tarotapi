class CardInterpretation < ApplicationRecord
  belongs_to :card

  # Validations
  validates :position_type, presence: true, inclusion: { in: [ "upright", "reversed" ] }
  validates :meaning, presence: true
  validates :interpretation_type, presence: true,
            inclusion: { in: [ "general", "love", "career", "spiritual", "financial", "health" ] }
  validates :version, presence: true, format: { with: /\Av\d+(\.\d+)*\z/, message: "must be in format v1, v1.0, etc." }

  # Scope for current versions
  scope :current, -> { where(is_current_version: true) }
  scope :by_version, ->(version) { where(version: version) }

  # Parse keywords array from string or use array
  def keywords=(value)
    if value.is_a?(String)
      super value.split(",").map(&:strip)
    else
      super
    end
  end

  # Create a new version
  def create_new_version(attributes = {})
    # Find any existing next versions and update their previous_version_id
    if next_version_id.present?
      next_version = self.class.find_by(id: next_version_id)
      if next_version
        next_version.update(previous_version_id: nil)
      end
    end

    # Mark the current version as no longer current
    update(is_current_version: false)

    # Create the new version
    new_version = self.class.create(
      attributes.reverse_merge(
        card_id: card_id,
        position_type: position_type,
        interpretation_type: interpretation_type,
        meaning: meaning,
        keywords: keywords,
        associations: associations,
        version: self.class.next_version_number(version),
        is_current_version: true,
        previous_version_id: id,
        published_at: Time.current
      )
    )

    # Update current record to point to new version
    update(next_version_id: new_version.id)

    new_version
  end

  # Calculate the next version number
  def self.next_version_number(current_version)
    if current_version.match(/\Av(\d+)(\.\d+)*\z/)
      major_version = $1.to_i
      "v#{major_version + 1}"
    else
      "v1"
    end
  end

  # Get the version history
  def version_history
    history = []

    # Get previous versions
    prev_id = previous_version_id
    while prev_id.present?
      prev_version = self.class.find_by(id: prev_id)
      break unless prev_version

      history.unshift(prev_version)
      prev_id = prev_version.previous_version_id
    end

    # Add current version
    history << self

    # Get next versions
    next_id = next_version_id
    while next_id.present?
      next_version = self.class.find_by(id: next_id)
      break unless next_version

      history << next_version
      next_id = next_version.next_version_id
    end

    history
  end
end
