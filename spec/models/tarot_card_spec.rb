require 'rails_helper'

RSpec.describe TarotCard, type: :model do
  it 'is a subclass of Card' do
    expect(described_class.superclass).to eq(Card)
  end

  it 'can be instantiated' do
    expect(FactoryBot.build(:tarot_card)).to be_valid
  end

  it 'shares the same table as Card' do
    expect(described_class.table_name).to eq(Card.table_name)
  end

  it 'can be saved to the database' do
    card = FactoryBot.create(:tarot_card)
    expect(card.persisted?).to be true
  end

  it 'can be found by the Card class' do
    tarot_card = FactoryBot.create(:tarot_card)
    expect(Card.find(tarot_card.id).id).to eq(tarot_card.id)
  end

  it 'can be found by its suit and rank' do
    tarot_card = FactoryBot.create(:tarot_card, suit: 'major', rank: 1)
    found_card = TarotCard.find_by(suit: 'major', rank: 1)
    expect(found_card.id).to eq(tarot_card.id)
  end
end
