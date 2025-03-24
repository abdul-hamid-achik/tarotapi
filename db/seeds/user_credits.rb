# Create user credits system
puts "Setting up user credits system..."

# Only run this if the UserCredit model/table doesn't exist yet
unless defined?(UserCredit) && ActiveRecord::Base.connection.table_exists?('user_credits')
  puts "UserCredit model/table not found. Creating migration..."

  # Create the migration file
  migration_path = "#{Rails.root}/db/migrate/#{Time.now.utc.strftime('%Y%m%d%H%M%S')}_create_user_credits.rb"

  File.open(migration_path, 'w') do |f|
    f.write <<~MIGRATION
      class CreateUserCredits < ActiveRecord::Migration[7.0]
        def change
          create_table :user_credits do |t|
            t.references :user, null: false, foreign_key: true
            t.integer :amount, null: false, default: 0
            t.string :description
            t.string :transaction_type
            t.datetime :expires_at
            t.timestamps
      #{'      '}
            t.index [:user_id, :transaction_type]
            t.index [:user_id, :expires_at]
          end
        end
      end
    MIGRATION
  end

  # Create the model file
  model_path = "#{Rails.root}/app/models/user_credit.rb"

  File.open(model_path, 'w') do |f|
    f.write <<~MODEL
      class UserCredit < ApplicationRecord
        belongs_to :user
      #{'  '}
        validates :amount, presence: true, numericality: { only_integer: true }
        validates :transaction_type, presence: true
      #{'  '}
        scope :active, -> { where('expires_at IS NULL OR expires_at > ?', Time.current) }
        scope :expired, -> { where('expires_at IS NOT NULL AND expires_at <= ?', Time.current) }
        scope :purchases, -> { where(transaction_type: 'purchase') }
        scope :usages, -> { where(transaction_type: 'usage') }
        scope :refunds, -> { where(transaction_type: 'refund') }
      #{'  '}
        # Get the current credit balance for a user
        def self.balance_for(user)
          user.user_credits.active.sum(:amount)
        end
      #{'  '}
        def expired?
          expires_at.present? && expires_at <= Time.current
        end
      end
    MODEL
  end

  # Add association to User model
  user_model_path = "#{Rails.root}/app/models/user.rb"
  if File.exist?(user_model_path)
    user_model_content = File.read(user_model_path)

    unless user_model_content.include?('has_many :user_credits')
      user_model_content.gsub!(/has_many :api_keys.*$/) do |match|
        "#{match}\n  has_many :user_credits, dependent: :destroy"
      end

      File.write(user_model_path, user_model_content)
    end
  end

  puts "Migration and model files created. Run 'rails db:migrate' to apply changes."
  puts "Then re-run the seeds to populate credit data."
  exit # Exit to allow the migration to be run
end

# Seed credit packages for the demo environment
if defined?(UserCredit) && ActiveRecord::Base.connection.table_exists?('user_credits')
  # Only seed credits in development or test
  if Rails.env.development? || Rails.env.test?
    # Find users to give credits to
    users = User.where(identity_provider: IdentityProvider.registered).limit(5)

    if users.present?
      puts "Adding sample credits to #{users.count} users..."

      users.each do |user|
        # Only add if user doesn't already have credits
        if user.user_credits.count == 0
          # Add a purchase of credits
          UserCredit.create!(
            user: user,
            amount: rand(5..20),
            description: "Welcome credits package",
            transaction_type: "purchase",
            expires_at: 1.year.from_now
          )

          # Add some usage for some users
          if rand > 0.5
            UserCredit.create!(
              user: user,
              amount: -rand(1..3),
              description: "Reading on #{Date.today - rand(1..10).days}",
              transaction_type: "usage",
              expires_at: nil
            )
          end

          # Add refund for some users
          if rand > 0.8
            UserCredit.create!(
              user: user,
              amount: rand(1..2),
              description: "Refund for failed reading",
              transaction_type: "refund",
              expires_at: nil
            )
          end
        end
      end

      puts "Created sample credits for users"
    else
      puts "No registered users found to seed credits"
    end
  end
end
