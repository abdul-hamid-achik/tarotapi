require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "validates required fields for registered users" do
    # Set up identity provider for registered user
    identity_provider = IdentityProvider.find_or_create_by(name: IdentityProvider::REGISTERED)

    # Create a registered user (which requires email and password)
    user = User.new(identity_provider: identity_provider)
    user.valid?

    assert_includes user.errors[:email], "can't be blank"
    assert_includes user.errors[:password], "can't be blank"
  end

  test "validates email format for registered users" do
    # Set up identity provider for registered user
    identity_provider = IdentityProvider.find_or_create_by(name: IdentityProvider::REGISTERED)

    user = User.new(
      email: "not_an_email",
      name: "test",
      password: "password",
      identity_provider: identity_provider
    )
    user.valid?

    assert_includes user.errors[:email], "is invalid"
  end

  test "validates email uniqueness" do
    # Create a user with a specific email
    identity_provider = IdentityProvider.find_or_create_by(name: IdentityProvider::REGISTERED)
    existing_user = User.create!(
      email: "duplicate@example.com",
      name: "Existing User",
      password: "password123",
      password_confirmation: "password123",
      identity_provider: identity_provider
    )

    # Try to create another user with the same email
    user = User.new(
      email: "duplicate@example.com",
      name: "New User",
      password: "different123",
      identity_provider: identity_provider
    )
    assert_not user.valid?
    assert_includes user.errors[:email], "has already been taken"
  end

  test "validates password length for registered users" do
    # Set up identity provider for registered user
    identity_provider = IdentityProvider.find_or_create_by(name: IdentityProvider::REGISTERED)

    user = User.new(
      email: "test@example.com",
      name: "test",
      password: "short",
      identity_provider: identity_provider
    )
    user.valid?

    assert_includes user.errors[:password], "is too short (minimum is 6 characters)"
  end

  test "admin? returns true for admin users" do
    admin_user = users(:one)
    admin_user.update(admin: true)
    assert admin_user.admin?
  end

  test "admin? returns false for non-admin users" do
    regular_user = users(:two)
    regular_user.update(admin: false)
    assert_not regular_user.admin?
  end

  test "anonymous? returns true for anonymous users" do
    # Set up identity provider for anonymous user
    identity_provider = IdentityProvider.find_or_create_by(name: IdentityProvider::ANONYMOUS)

    user = User.new(identity_provider: identity_provider)
    assert user.anonymous?
  end

  test "registered? returns true for registered users" do
    # Set up identity provider for registered user
    identity_provider = IdentityProvider.find_or_create_by(name: IdentityProvider::REGISTERED)

    user = User.new(identity_provider: identity_provider)
    assert user.registered?
  end

  test "agent? returns true for agent users" do
    # Set up identity provider for agent user
    identity_provider = IdentityProvider.find_or_create_by(name: IdentityProvider::AGENT)

    user = User.new(identity_provider: identity_provider)
    assert user.agent?
  end

  test "has secure password" do
    user = User.create(
      email: "secure@example.com",
      name: "Secure User",
      password: "securepass",
      identity_provider: IdentityProvider.find_or_create_by(name: IdentityProvider::REGISTERED)
    )
    assert user.authenticate("securepass")
    assert_not user.authenticate("wrongpass")
  end

  test "password digest is set on create" do
    user = User.create(
      email: "digest@example.com",
      name: "Digest User",
      password: "digestpass",
      identity_provider: IdentityProvider.find_or_create_by(name: IdentityProvider::REGISTERED)
    )
    assert user.persisted?
    assert_not_nil user.encrypted_password
  end

  test "password not required for anonymous users" do
    user = User.new(
      identity_provider: IdentityProvider.find_or_create_by(name: IdentityProvider::ANONYMOUS),
      external_id: SecureRandom.uuid
    )
    assert_not user.password_required?
  end
end
