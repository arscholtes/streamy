# test/models/user_test.rb
# This file tests the User model to ensure authentication works correctly
# Learn more about Rails testing: https://guides.rubyonrails.org/testing.html
# Learn about TDD: https://en.wikipedia.org/wiki/Test-driven_development

require "test_helper"

class UserTest < ActiveSupport::TestCase
  # Setup runs before each test - creates a valid user for testing
  def setup
    # Create a user with valid attributes to use in our tests
    @user = User.new(
      username: "testuser",              # Unique username
      email: "test@example.com",         # Unique email
      password: "password123",           # Plain text password (will be hashed)
      password_confirmation: "password123" # Must match password
    )
  end

  # Test that a user with valid attributes can be saved
  test "should be valid with valid attributes" do
    # assert checks if the statement is true - if not, the test fails
    assert @user.valid?, "User should be valid with all required attributes"
  end

  # Test validations - these ensure data integrity
  # Presence validations ensure required fields aren't blank
  test "should require a username" do
    @user.username = nil # Set username to nil (blank)
    # User should NOT be valid without a username
    assert_not @user.valid?, "User should be invalid without username"
    # Check that the error message is added to the username field
    assert_includes @user.errors[:username], "can't be blank"
  end

  test "should require an email" do
    @user.email = nil # Set email to nil
    assert_not @user.valid?, "User should be invalid without email"
    assert_includes @user.errors[:email], "can't be blank"
  end

  test "should require a password" do
    @user.password = nil # Set password to nil
    @user.password_confirmation = nil
    assert_not @user.valid?, "User should be invalid without password"
  end

  # Uniqueness validations prevent duplicate usernames/emails
  # This is crucial for authentication - each user must be unique
  test "username should be unique" do
    # Save the first user to the database
    @user.save
    # Create a duplicate user with the same username
    duplicate_user = User.new(
      username: @user.username, # Same username - should fail
      email: "different@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    # The duplicate should NOT be valid
    assert_not duplicate_user.valid?, "Username should be unique"
    assert_includes duplicate_user.errors[:username], "has already been taken"
  end

  test "email should be unique" do
    @user.save
    # Create a duplicate user with the same email
    duplicate_user = User.new(
      username: "differentuser",
      email: @user.email, # Same email - should fail
      password: "password123",
      password_confirmation: "password123"
    )
    assert_not duplicate_user.valid?, "Email should be unique"
    assert_includes duplicate_user.errors[:email], "has already been taken"
  end

  # Case insensitivity - prevents users from creating "John" and "john" as separate accounts
  test "username should be case insensitive" do
    @user.username = "TestUser" # Mixed case
    @user.save
    # Try to create a user with lowercase version of same username
    duplicate_user = User.new(
      username: "testuser", # Same username, different case
      email: "different@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    assert_not duplicate_user.valid?, "Username should be case insensitive"
  end

  test "email should be case insensitive" do
    @user.email = "Test@Example.COM"
    @user.save
    duplicate_user = User.new(
      username: "differentuser",
      email: "test@example.com", # Same email, different case
      password: "password123",
      password_confirmation: "password123"
    )
    assert_not duplicate_user.valid?, "Email should be case insensitive"
  end

  # Format validations ensure data is in the correct format
  test "email should have valid format" do
    # Array of invalid email formats
    invalid_emails = [
      "user@",           # Missing domain
      "@example.com",    # Missing username
      "user.example.com", # Missing @
      "user@example",    # Missing TLD
      "user name@example.com" # Space in username
    ]

    # Loop through each invalid email and test it
    invalid_emails.each do |invalid_email|
      @user.email = invalid_email
      # User should NOT be valid with invalid email format
      assert_not @user.valid?, "#{invalid_email} should be invalid"
    end
  end

  # Length validations prevent abuse and ensure reasonable data sizes
  test "username should have minimum length" do
    @user.username = "ab" # Only 2 characters (too short)
    assert_not @user.valid?, "Username should be at least 3 characters"
  end

  test "username should have maximum length" do
    @user.username = "a" * 51 # 51 characters (too long)
    assert_not @user.valid?, "Username should be at most 50 characters"
  end

  test "password should have minimum length" do
    @user.password = "12345" # Only 5 characters (too short)
    @user.password_confirmation = "12345"
    assert_not @user.valid?, "Password should be at least 6 characters"
  end

  # Test has_secure_password functionality
  # has_secure_password uses bcrypt to hash passwords
  # Learn more: https://api.rubyonrails.org/classes/ActiveModel/SecurePassword/ClassMethods.html
  test "password should be hashed" do
    @user.save
    # password_digest is the hashed version stored in database
    # It should NOT equal the plain text password
    assert_not_equal "password123", @user.password_digest
    # password_digest should exist (not nil)
    assert_not_nil @user.password_digest
  end

  test "should authenticate with correct password" do
    @user.save
    # authenticate method is provided by has_secure_password
    # It compares the provided password with the hashed password_digest
    authenticated_user = @user.authenticate("password123")
    # Should return the user object if password is correct
    assert_equal @user, authenticated_user
  end

  test "should not authenticate with incorrect password" do
    @user.save
    # authenticate returns false if password is incorrect
    assert_not @user.authenticate("wrongpassword")
  end

  test "password and password_confirmation should match" do
    @user.password = "password123"
    @user.password_confirmation = "different123" # Doesn't match
    # User should NOT be valid if passwords don't match
    assert_not @user.valid?, "Password confirmation should match password"
  end

  # Test associations - relationships with other models
  test "should have many streams" do
    # Check that the User model has the has_many :streams association
    assert_respond_to @user, :streams, "User should have streams association"
  end

  test "should destroy associated streams when user is destroyed" do
    @user.save
    # Create a stream belonging to this user
    @user.streams.create!(
      title: "Test Stream",
      stream_key: SecureRandom.hex(20), # Generate random stream key
      status: "offline"
    )
    # Count how many streams exist before deletion
    assert_difference "Stream.count", -1 do
      # When we destroy the user, their streams should also be destroyed
      # This prevents orphaned records in the database
      @user.destroy
    end
  end

  # Test callbacks - methods that run automatically at certain times
  # Learn more: https://guides.rubyonrails.org/active_record_callbacks.html
  test "should downcase email before saving" do
    mixed_case_email = "TeSt@ExAmPlE.CoM"
    @user.email = mixed_case_email
    @user.save
    # Email should be converted to lowercase in the database
    # This ensures case-insensitive uniqueness
    assert_equal mixed_case_email.downcase, @user.reload.email
  end

  test "should downcase username before saving" do
    mixed_case_username = "TestUser123"
    @user.username = mixed_case_username
    @user.save
    # Username should be converted to lowercase in the database
    assert_equal mixed_case_username.downcase, @user.reload.username
  end

  # Test automatic stream key generation
  test "should generate stream key after creation" do
    @user.save
    # reload fetches the latest data from the database
    @user.reload
    # stream_key should be automatically generated
    assert_not_nil @user.stream_key, "Stream key should be generated"
    # Stream keys should be 40 characters (hex format from SecureRandom)
    assert_equal 40, @user.stream_key.length
  end

  test "should generate unique stream keys for different users" do
    @user.save
    # Create another user
    user2 = User.create!(
      username: "testuser2",
      email: "test2@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    # Stream keys should be different (SecureRandom ensures this)
    assert_not_equal @user.stream_key, user2.stream_key
  end
end
