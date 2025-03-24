require 'rails_helper'

RSpec.describe SpreadService do
  describe '.system_spreads' do
    let(:yaml_data) do
      [
        {
          "name" => "Celtic Cross",
          "description" => "A classic 10-card spread",
          "positions" => [
            { "name" => "Present" },
            { "name" => "Challenge" },
            { "name" => "Past" },
            { "name" => "Future" }
          ]
        },
        {
          "name" => "Three Card",
          "description" => "A simple 3-card spread",
          "positions" => [
            { "name" => "Past" },
            { "name" => "Present" },
            { "name" => "Future" }
          ]
        }
      ]
    end

    before do
      allow(described_class).to receive(:yaml_data).and_return(yaml_data)
    end

    it 'creates system spreads from yaml data' do
      expect(described_class).to receive(:find_or_create_system_spread).twice.and_call_original
      spreads = described_class.system_spreads
      expect(spreads.size).to eq(2)
      expect(spreads.first.name).to eq("Celtic Cross")
      expect(spreads.last.name).to eq("Three Card")
    end

    it 'memoizes the result' do
      # Call once to cache
      described_class.system_spreads

      # Should not call find_or_create_system_spread again
      expect(described_class).not_to receive(:find_or_create_system_spread)
      described_class.system_spreads
    end
  end

  describe '.find_or_create_system_spread' do
    let(:spread_data) do
      {
        "name" => "Celtic Cross",
        "description" => "A classic 10-card spread",
        "positions" => [
          { "name" => "Present" },
          { "name" => "Challenge" },
          { "name" => "Past" },
          { "name" => "Future" }
        ]
      }
    end

    context 'when spread with name already exists' do
      let!(:existing_spread) { create(:spread, name: "Celtic Cross") }

      it 'returns the existing spread' do
        result = described_class.find_or_create_system_spread(spread_data)
        expect(result).to eq(existing_spread)
        expect(Spread.count).to eq(1)
      end
    end

    context 'when spread does not exist' do
      let!(:admin_user) { create(:user, email: "admin@tarotapi.cards", admin: true) }

      it 'creates a new system spread' do
        expect {
          described_class.find_or_create_system_spread(spread_data)
        }.to change(Spread, :count).by(1)

        new_spread = Spread.last
        expect(new_spread.name).to eq("Celtic Cross")
        expect(new_spread.description).to eq("A classic 10-card spread")
        expect(new_spread.num_cards).to eq(4)
        expect(new_spread.is_system).to be true
        expect(new_spread.is_public).to be true
        expect(new_spread.user).to eq(admin_user)

        # Check positions
        expect(new_spread.positions).to eq({
          "1" => "Present",
          "2" => "Challenge",
          "3" => "Past",
          "4" => "Future"
        })
      end

      context 'when admin user does not exist' do
        it 'creates an admin user' do
          User.delete_all

          expect {
            described_class.find_or_create_system_spread(spread_data)
          }.to change(User, :count).by(1)

          admin = User.last
          expect(admin.email).to eq("admin@tarotapi.cards")
          expect(admin.admin).to be true
        end
      end

      context 'when positions are in hash format' do
        let(:spread_data) do
          {
            "name" => "Simple Spread",
            "description" => "A simple spread",
            "positions" => {
              "1" => "Past",
              "2" => "Present",
              "3" => "Future"
            }
          }
        end

        it 'creates spread with the provided positions hash' do
          spread = described_class.find_or_create_system_spread(spread_data)
          expect(spread.positions).to eq(spread_data["positions"])
          expect(spread.num_cards).to eq(3)
        end
      end
    end
  end

  describe '.default_spread' do
    it 'returns the first system spread' do
      system_spreads = [ double("spread1"), double("spread2") ]
      allow(described_class).to receive(:system_spreads).and_return(system_spreads)

      expect(described_class.default_spread).to eq(system_spreads.first)
    end
  end

  describe '.spread_for_time' do
    before do
      # Create test spreads
      @celtic_cross = create(:spread, name: "celtic cross")
      @daily_draw = create(:spread, name: "daily draw")
      @three_card = create(:spread, name: "three card")

      allow(described_class).to receive(:system_spreads).and_return(
        [ @celtic_cross, @daily_draw, @three_card ]
      )
    end

    it 'returns celtic cross for late night (0-5 hours)' do
      time = Time.new(2023, 1, 1, 3, 0, 0)
      expect(described_class.spread_for_time(time)).to eq(@celtic_cross)
    end

    it 'returns daily draw for morning (6-11 hours)' do
      time = Time.new(2023, 1, 1, 9, 0, 0)
      expect(described_class.spread_for_time(time)).to eq(@daily_draw)
    end

    it 'returns three card for afternoon (12-17 hours)' do
      time = Time.new(2023, 1, 1, 15, 0, 0)
      expect(described_class.spread_for_time(time)).to eq(@three_card)
    end

    it 'returns celtic cross for evening (18-23 hours)' do
      time = Time.new(2023, 1, 1, 20, 0, 0)
      expect(described_class.spread_for_time(time)).to eq(@celtic_cross)
    end

    context 'when a specific spread is not found' do
      it 'falls back to the default spread' do
        allow(described_class).to receive(:find_by_name).with("celtic cross").and_return(nil)
        allow(described_class).to receive(:default_spread).and_return(@daily_draw)

        time = Time.new(2023, 1, 1, 3, 0, 0)
        expect(described_class.spread_for_time(time)).to eq(@daily_draw)
      end
    end
  end

  describe '.find_by_name' do
    it 'finds a system spread by name' do
      spreads = [
        double("spread1", name: "three card"),
        double("spread2", name: "celtic cross")
      ]
      allow(described_class).to receive(:system_spreads).and_return(spreads)

      result = described_class.send(:find_by_name, "celtic cross")
      expect(result).to eq(spreads.last)
    end

    it 'returns default spread if name not found' do
      spreads = [ double("spread1", name: "three card") ]
      allow(described_class).to receive(:system_spreads).and_return(spreads)
      allow(described_class).to receive(:default_spread).and_return(spreads.first)

      result = described_class.send(:find_by_name, "nonexistent")
      expect(result).to eq(spreads.first)
    end
  end

  describe '.yaml_data' do
    it 'loads data from spreads.yml file' do
      yaml_file_path = Rails.root.join("config", "spreads.yml")
      yaml_data = [ { "name" => "Test Spread" } ]

      expect(YAML).to receive(:load_file).with(yaml_file_path).and_return(yaml_data)
      expect(described_class.send(:yaml_data)).to eq(yaml_data)
    end
  end

  describe '.create_admin_user' do
    it 'creates an admin user with the right attributes' do
      expect {
        described_class.send(:create_admin_user)
      }.to change(User, :count).by(1)

      admin = User.last
      expect(admin.email).to eq("admin@tarotapi.cards")
      expect(admin.name).to eq("admin")
      expect(admin.admin).to be true
    end
  end
end
