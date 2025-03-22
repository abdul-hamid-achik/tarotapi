class Membership < ApplicationRecord
  # Associations
  belongs_to :user
  belongs_to :organization

  # Validations
  validates :user_id, presence: true, uniqueness: { scope: :organization_id, message: 'is already a member of this organization' }
  validates :organization_id, presence: true
  validates :role, presence: true, inclusion: { in: %w[admin member] }
  validates :status, presence: true, inclusion: { in: %w[invited active suspended] }

  # Enums
  enum role: {
    admin: 'admin',
    member: 'member'
  }

  enum status: {
    active: 'active',
    invited: 'invited',
    suspended: 'suspended'
  }

  # Scopes
  scope :active, -> { where(status: :active) }
  scope :admins, -> { where(role: :admin) }
  scope :members, -> { where(role: :member) }
  scope :by_role, ->(role) { where(role: role) }

  # Callbacks
  before_create :set_default_status
  after_create :track_member_count
  after_destroy :track_member_count

  # Instance methods
  def admin?
    role == 'admin'
  end

  def member?
    role == 'member'
  end

  def active?
    status == 'active'
  end

  def invited?
    status == 'invited'
  end

  def suspended?
    status == 'suspended'
  end

  def activate!
    update!(status: :active)
  end

  def suspend!
    update!(status: :suspended)
  end

  def touch_last_active!
    update!(last_active_at: Time.current)
  end

  private

  def set_default_status
    self.status ||= :invited
  end

  def track_member_count
    return unless organization
    
    current_count = organization.memberships.active.count
    max_members = organization.features['max_members']
    
    if current_count >= max_members
      organization.track_usage!(:member_limit_reached, {
        current_count: current_count,
        max_members: max_members
      })
    end
  end
end 