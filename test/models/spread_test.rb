require "test_helper"

class SpreadTest < ActiveSupport::TestCase
  test "validates required fields" do
    spread = Spread.new
    assert_not spread.valid?
    assert_includes spread.errors[:name], "can't be blank"
    assert_includes spread.errors[:description], "can't be blank"
    assert_includes spread.errors[:positions], "can't be blank"
  end
  
  test "validates name uniqueness" do
    existing_spread = spreads(:one)
    spread = Spread.new(name: existing_spread.name, 
                      description: "test description", 
                      positions: [{ name: "test", description: "test" }],
                      user: users(:one))
    assert_not spread.valid?
    assert_includes spread.errors[:name], "has already been taken"
  end
  
  test "system? method returns correct value" do
    assert spreads(:one).system?
    
    custom_spread = Spread.new(name: "Custom Spread", 
                             description: "test description",
                             positions: [{ name: "test", description: "test" }],
                             is_system: false,
                             user: users(:one))
    assert_not custom_spread.system?
  end
  
  test "default scope orders by name" do
    spreads = Spread.all
    assert_equal spreads.sort_by(&:name), spreads
  end
  
  test "scope system_spreads returns only system spreads" do
    system_spreads = Spread.system_spreads
    assert system_spreads.all?(&:is_system)
  end
  
  test "scope custom_spreads returns only non-system spreads" do
    custom_spreads = Spread.custom_spreads
    assert custom_spreads.none?(&:is_system)
  end
  
  test "scope public_spreads returns only public spreads" do
    public_spreads = Spread.public_spreads
    assert public_spreads.all?(&:is_public)
  end
end
