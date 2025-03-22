require "test_helper"

class ReadingSessionTest < ActiveSupport::TestCase
  test "validates required fields" do
    session = ReadingSession.new
    assert_not session.valid?
    assert_includes session.errors[:question], "can't be blank"
    assert_includes session.errors[:user], "must exist"
  end

  test "generates session_id before validation if not set" do
    session = ReadingSession.new(
      question: "Will I find success?",
      user: users(:one),
      spread: spreads(:one)
    )
    session.valid?
    assert_not_nil session.session_id
  end

  test "does not override session_id if set" do
    custom_id = "custom-session-id"
    session = ReadingSession.new(
      question: "Will I find success?",
      user: users(:one),
      spread: spreads(:one),
      session_id: custom_id
    )
    session.valid?
    assert_equal custom_id, session.session_id
  end

  test "sets reading_date before validation if not set" do
    # Save the current time
    freeze_time = Time.current

    # Use a stub implementation that doesn't rely on mocha
    original_current = Time.method(:current)
    Time.define_singleton_method(:current) { freeze_time }

    begin
      session = ReadingSession.new(
        question: "Will I find success?",
        user: users(:one),
        spread: spreads(:one)
      )
      session.valid?
      assert_equal freeze_time, session.reading_date
    ensure
      # Restore the original method
      Time.singleton_class.send(:remove_method, :current)
      Time.define_singleton_method(:current, original_current)
    end
  end

  test "does not override reading_date if set" do
    custom_date = 2.days.ago
    session = ReadingSession.new(
      question: "Will I find success?",
      user: users(:one),
      spread: spreads(:one),
      reading_date: custom_date
    )
    session.valid?
    assert_equal custom_date, session.reading_date
  end

  test "sets status to 'completed' by default" do
    session = ReadingSession.new(
      question: "Will I find success?",
      user: users(:one),
      spread: spreads(:one)
    )
    session.valid?
    assert_equal "completed", session.status
  end

  test "does not override status if set" do
    session = ReadingSession.new(
      question: "Will I find success?",
      user: users(:one),
      spread: spreads(:one),
      status: "pending"
    )
    session.valid?
    assert_equal "pending", session.status
  end

  test "belongs to user" do
    session = reading_sessions(:one)
    assert_instance_of User, session.user
  end

  test "has many card readings" do
    session = reading_sessions(:one)
    card_reading = CardReading.create!(
      position: "test position",
      user: session.user,
      tarot_card: tarot_cards(:one),
      reading_session: session
    )

    assert_includes session.card_readings, card_reading
  end

  test "destroys dependent card readings when destroyed" do
    # Create a new session to avoid destroying fixtures
    new_session = ReadingSession.create!(
      question: "Test question for destroy test",
      user: users(:one),
      spread: spreads(:one)
    )

    # Create a reading specifically for this test
    card_reading = CardReading.create!(
      position: "test position",
      user: new_session.user,
      tarot_card: tarot_cards(:one),
      reading_session: new_session
    )

    assert_difference -> { CardReading.where(id: card_reading.id).count }, -1 do
      new_session.destroy
    end
  end
end
