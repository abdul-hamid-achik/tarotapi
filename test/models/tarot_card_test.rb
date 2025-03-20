require "test_helper"

class TarotCardTest < ActiveSupport::TestCase
  test "validates required fields" do
    card = TarotCard.new
    assert_not card.valid?
    assert_includes card.errors[:name], "can't be blank"
    assert_includes card.errors[:arcana], "can't be blank"
    assert_includes card.errors[:description], "can't be blank"
  end
  
  test "validates name uniqueness" do
    existing_card = tarot_cards(:one)
    card = TarotCard.new(
      name: existing_card.name,
      arcana: "major",
      description: "test description"
    )
    assert_not card.valid?
    assert_includes card.errors[:name], "has already been taken"
  end
  
  test "major_arcana? returns true for major arcana cards" do
    card = TarotCard.new(arcana: "major")
    assert card.major_arcana?
    
    card.arcana = "Major"
    assert card.major_arcana?
  end
  
  test "major_arcana? returns false for minor arcana cards" do
    card = TarotCard.new(arcana: "minor")
    assert_not card.major_arcana?
  end
  
  test "minor_arcana? returns true for minor arcana cards" do
    card = TarotCard.new(arcana: "minor")
    assert card.minor_arcana?
    
    card.arcana = "Minor"
    assert card.minor_arcana?
  end
  
  test "minor_arcana? returns false for major arcana cards" do
    card = TarotCard.new(arcana: "major")
    assert_not card.minor_arcana?
  end
  
  test "validates suit presence for minor arcana" do
    card = TarotCard.new(
      name: "test card",
      arcana: "minor",
      description: "test description"
    )
    assert_not card.valid?
    assert_includes card.errors[:suit], "can't be blank"
  end
  
  test "does not validate suit presence for major arcana" do
    card = TarotCard.new(
      name: "test major card",
      arcana: "major",
      description: "test description",
      rank: "0"
    )
    card.valid?
    assert_not card.errors.include?(:suit)
  end
  
  test "validates rank presence for major arcana" do
    card = TarotCard.new(
      name: "test major card",
      arcana: "major",
      description: "test description"
    )
    assert_not card.valid?
    assert_includes card.errors[:rank], "can't be blank"
  end
end
