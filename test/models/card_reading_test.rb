require "test_helper"

class CardReadingTest < ActiveSupport::TestCase
  test "validates required fields" do
    card_reading = CardReading.new
    assert_not card_reading.valid?
    assert_includes card_reading.errors[:position], "can't be blank"
    assert_includes card_reading.errors[:user], "must exist"
    assert_includes card_reading.errors[:tarot_card], "must exist"
  end

  test "is_reversed has default value" do
    # Create a reading session first
    session = ReadingSession.create!(
      question: "Test question",
      user: users(:one),
      spread: spreads(:one)
    )

    card_reading = CardReading.new(
      position: "test position",
      user: users(:one),
      tarot_card: tarot_cards(:one),
      reading_session: session
    )
    card_reading.save
    assert_equal false, card_reading.is_reversed
  end

  test "sets reading_date before creation if not set" do
    # Save the current time
    freeze_time = Time.current

    # Create a reading session first
    session = ReadingSession.create!(
      question: "Test question",
      user: users(:one),
      spread: spreads(:one)
    )

    # Use a stub implementation that doesn't rely on mocha
    original_current = Time.method(:current)
    Time.define_singleton_method(:current) { freeze_time }

    begin
      card_reading = CardReading.new(
        position: "test position",
        user: users(:one),
        tarot_card: tarot_cards(:one),
        reading_session: session
      )
      card_reading.save

      assert_equal freeze_time, card_reading.reading_date
    ensure
      # Restore the original method
      Time.singleton_class.send(:remove_method, :current)
      Time.define_singleton_method(:current, original_current)
    end
  end

  test "does not override reading_date if set" do
    # Create a reading session first
    session = ReadingSession.create!(
      question: "Test question",
      user: users(:one),
      spread: spreads(:one)
    )

    custom_date = 3.days.ago
    card_reading = CardReading.new(
      position: "test position",
      user: users(:one),
      tarot_card: tarot_cards(:one),
      reading_date: custom_date,
      reading_session: session
    )
    card_reading.save

    assert_equal custom_date, card_reading.reading_date
  end

  test "belongs to user" do
    card_reading = card_readings(:one)
    assert_instance_of User, card_reading.user
  end

  test "belongs to tarot card" do
    card_reading = card_readings(:one)
    assert_instance_of TarotCard, card_reading.tarot_card
  end

  test "can belong to spread" do
    card_reading = card_readings(:one)
    card_reading.spread = spreads(:one)
    card_reading.save

    assert_instance_of Spread, card_reading.spread
  end

  test "spread is optional" do
    card_reading = CardReading.new(
      position: "test position",
      user: users(:one),
      tarot_card: tarot_cards(:one)
    )
    assert card_reading.valid?
  end
end
