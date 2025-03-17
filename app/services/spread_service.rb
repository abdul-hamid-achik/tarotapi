class SpreadService
  class << self
    def system_spreads
      @system_spreads ||= begin
        spreads_data = yaml_data
        spreads_data.map do |spread_data|
          find_or_create_system_spread(spread_data)
        end
      end
    end

    def find_or_create_system_spread(spread_data)
      # first try to find an existing spread with this name
      spread = Spread.find_by(name: spread_data['name'])
      return spread if spread

      # if not found, create a new one with a regular user
      user = User.first || create_test_user
      
      Spread.create!(
        name: spread_data['name'],
        description: spread_data['description'],
        positions: spread_data['positions'],
        is_public: true,
        is_system: true,
        user: user
      )
    end

    def default_spread
      system_spreads.first
    end

    def spread_for_time(time = Time.current)
      case 
      when time.hour.between?(0, 5)
        find_by_name('celtic cross') # deep night readings
      when time.hour.between?(6, 11)
        find_by_name('daily draw') # morning guidance
      when time.hour.between?(12, 17)
        find_by_name('three card') # afternoon insights
      else
        find_by_name('celtic cross') # evening contemplation
      end
    end

    private

    def yaml_data
      @yaml_data ||= YAML.load_file(Rails.root.join('config', 'spreads.yml'))
    end

    def create_test_user
      User.create!(
        email: 'test@example.com',
        identity_provider: IdentityProvider.registered
      )
    end

    def find_by_name(name)
      system_spreads.find { |spread| spread.name == name } || default_spread
    end
  end
end 