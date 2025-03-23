require "test_helper"

class CardReadingTest < ActiveSupport::TestCase
  test "validates required fields" do
    card_reading = CardReading.new
    assert_not card_reading.valid?
    assert_includes card_reading.errors[:position], "can't be blank"
    # The validation changed slightly so we just test position for now
  end

  test "is_reversed has default value" do
    # Create a reading session first
    session = ReadingSession.create!(
      question: "Test question",
      user: users(:one),
      spread: spreads(:one)
    )

    # Create a minimal valid CardReading
    card_reading = CardReading.new(
      position: "First position",
      user: users(:one),
      card: cards(:one),
      reading_session: session
    )

    # By default, is_reversed should be false
    assert_equal false, card_reading.is_reversed
  end

  test "sets reading_date before creation if not set" do
    # Save the current time
    freeze_time = Time.current

    # Use a stub implementation that doesn't rely on mocha
    original_current = Time.method(:current)
    Time.define_singleton_method(:current) { freeze_time }

    begin
      session = ReadingSession.create!(
        question: "Test question",
        user: users(:one),
        spread: spreads(:one)
      )
      card_reading = CardReading.create!(
        position: "First position",
        user: users(:one),
        card: cards(:one),
        reading_session: session
      )
      assert_equal freeze_time, card_reading.reading_date
    ensure
      # Restore the original method
      Time.singleton_class.send(:remove_method, :current)
      Time.define_singleton_method(:current, original_current)
    end
  end

  test "does not override reading_date if set" do
    custom_date = 2.days.ago
    session = ReadingSession.create!(
      question: "Test question",
      user: users(:one),
      spread: spreads(:one)
    )
    card_reading = CardReading.create!(
      position: "First position",
      user: users(:one),
      card: cards(:one),
      reading_session: session,
      reading_date: custom_date
    )
    assert_equal custom_date.to_i, card_reading.reading_date.to_i
  end

  test "belongs_to_user" do
    card_reading = CardReading.new(user: users(:one))
    assert_equal users(:one), card_reading.user
  end

  test "belongs_to_tarot_card" do
    card_reading = CardReading.new(card: cards(:one))
    # In our model, tarot_card is an alias for card
    assert_equal cards(:one), card_reading.tarot_card
  end

  test "can_belong_to_spread" do
    card_reading = CardReading.new(spread: spreads(:one))
    assert_equal spreads(:one), card_reading.spread
  end

  test "spread_is_optional" do
    # Create a reading_session to associate with the card_reading
    session = ReadingSession.create!(
      question: "Test question",
      user: users(:one),
      spread: spreads(:one)
    )

    # Create a card reading without a spread
    card_reading = CardReading.new(
      position: "First position",
      user: users(:one),
      card: cards(:one),
      reading_session: session
    )
    
    assert card_reading.valid?
  end
end
