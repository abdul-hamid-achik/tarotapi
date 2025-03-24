require 'rails_helper'

RSpec.describe CardInterpretation, type: :model do
  describe 'associations' do
    it { should belong_to(:card) }
  end

  describe 'validations' do
    it { should validate_presence_of(:position_type) }
    it { should validate_inclusion_of(:position_type).in_array([ "upright", "reversed" ]) }

    it { should validate_presence_of(:meaning) }

    it { should validate_presence_of(:interpretation_type) }
    it { should validate_inclusion_of(:interpretation_type).in_array([ "general", "love", "career", "spiritual", "financial", "health" ]) }

    it { should validate_presence_of(:version) }

    context 'version format validation' do
      it 'accepts valid version formats' do
        valid_versions = [ "v1", "v1.0", "v2.1.3" ]
        valid_versions.each do |version|
          interpretation = build(:card_interpretation, version: version)
          expect(interpretation).to be_valid
        end
      end

      it 'rejects invalid version formats' do
        invalid_versions = [ "1.0", "version 1", "v", "v-1" ]
        invalid_versions.each do |version|
          interpretation = build(:card_interpretation, version: version)
          expect(interpretation).not_to be_valid
          expect(interpretation.errors[:version]).to include("must be in format v1, v1.0, etc.")
        end
      end
    end
  end

  describe 'scopes' do
    let!(:current_interpretation) { create(:card_interpretation, is_current_version: true) }
    let!(:old_interpretation) { create(:card_interpretation, is_current_version: false) }
    let!(:v1_interpretation) { create(:card_interpretation, version: "v1") }
    let!(:v2_interpretation) { create(:card_interpretation, version: "v2") }

    describe '.current' do
      it 'returns only current versions' do
        expect(described_class.current).to include(current_interpretation)
        expect(described_class.current).not_to include(old_interpretation)
      end
    end

    describe '.by_version' do
      it 'returns interpretations with the specified version' do
        expect(described_class.by_version("v1")).to include(v1_interpretation)
        expect(described_class.by_version("v1")).not_to include(v2_interpretation)
      end
    end
  end

  describe '#keywords=' do
    context 'when given a string' do
      it 'splits by commas and stores as an array' do
        interpretation = build(:card_interpretation)
        interpretation.keywords = "beginnings, potential, journey"
        expect(interpretation.keywords).to eq([ "beginnings", "potential", "journey" ])
      end

      it 'handles whitespace correctly' do
        interpretation = build(:card_interpretation)
        interpretation.keywords = " beginnings,  potential ,journey"
        expect(interpretation.keywords).to eq([ "beginnings", "potential", "journey" ])
      end
    end

    context 'when given an array' do
      it 'stores the array directly' do
        interpretation = build(:card_interpretation)
        keywords_array = [ "beginnings", "potential", "journey" ]
        interpretation.keywords = keywords_array
        expect(interpretation.keywords).to eq(keywords_array)
      end
    end
  end

  describe '#create_new_version' do
    let(:interpretation) { create(:card_interpretation, version: "v1") }

    it 'creates a new version with incremented version number' do
      expect {
        interpretation.create_new_version(meaning: "Updated meaning")
      }.to change(CardInterpretation, :count).by(1)

      new_version = CardInterpretation.last
      expect(new_version.version).to eq("v2")
      expect(new_version.meaning).to eq("Updated meaning")
      expect(new_version.is_current_version).to be true
    end

    it 'marks the previous version as not current' do
      interpretation.create_new_version
      expect(interpretation.reload.is_current_version).to be false
    end

    it 'sets up the version linkage correctly' do
      new_version = interpretation.create_new_version

      expect(interpretation.reload.next_version_id).to eq(new_version.id)
      expect(new_version.previous_version_id).to eq(interpretation.id)
    end

    context 'with an existing chain of versions' do
      let!(:original) { create(:card_interpretation, version: "v1") }
      let!(:middle) { original.create_new_version(meaning: "Middle version") }

      it 'updates links correctly when adding to the end of the chain' do
        newest = middle.create_new_version(meaning: "Newest version")

        expect(original.reload.next_version_id).to eq(middle.id)
        expect(middle.reload.next_version_id).to eq(newest.id)
        expect(middle.reload.previous_version_id).to eq(original.id)
        expect(newest.reload.previous_version_id).to eq(middle.id)
      end

      it 'handles out-of-order updates correctly' do
        # Creating a new version from the original should detach middle
        newest = original.create_new_version(meaning: "Branch version")

        expect(original.reload.next_version_id).to eq(newest.id)
        expect(middle.reload.previous_version_id).to be_nil
      end
    end
  end

  describe '.next_version_number' do
    it 'increments the major version number' do
      expect(described_class.next_version_number("v1")).to eq("v2")
      expect(described_class.next_version_number("v5")).to eq("v6")
      expect(described_class.next_version_number("v9.2")).to eq("v10")
    end

    it 'returns v1 for invalid version formats' do
      expect(described_class.next_version_number("invalid")).to eq("v1")
    end
  end

  describe '#version_history' do
    it 'returns the complete version history in chronological order' do
      interpretation = create(:card_interpretation, :with_version_history)
      history = interpretation.version_history

      expect(history.size).to eq(2)
      expect(history.first.version).to eq("v1")
      expect(history.last.version).to eq("v2")
    end

    it 'handles complex history chains' do
      v1 = create(:card_interpretation, version: "v1")
      v2 = v1.create_new_version(version: "v2")
      v3 = v2.create_new_version(version: "v3")

      expect(v1.version_history.size).to eq(3)
      expect(v2.version_history.size).to eq(3)
      expect(v3.version_history.size).to eq(3)

      expect(v1.version_history.map(&:version)).to eq([ "v1", "v2", "v3" ])
      expect(v3.version_history.map(&:version)).to eq([ "v1", "v2", "v3" ])
    end
  end

  describe 'factory' do
    it 'has a valid factory' do
      expect(build(:card_interpretation)).to be_valid
    end

    it 'has a valid factory with :reversed trait' do
      interpretation = build(:card_interpretation, :reversed)
      expect(interpretation).to be_valid
      expect(interpretation.position_type).to eq("reversed")
    end

    it 'has a valid factory with :love trait' do
      interpretation = build(:card_interpretation, :love)
      expect(interpretation).to be_valid
      expect(interpretation.interpretation_type).to eq("love")
    end

    it 'has a valid factory with :career trait' do
      interpretation = build(:card_interpretation, :career)
      expect(interpretation).to be_valid
      expect(interpretation.interpretation_type).to eq("career")
    end

    it 'has a valid factory with :with_version_history trait' do
      interpretation = create(:card_interpretation, :with_version_history)
      expect(interpretation).to be_valid
      expect(interpretation.version_history.size).to eq(2)
    end
  end
end
