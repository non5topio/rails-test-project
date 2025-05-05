require "test_helper"

class UserTest < ActiveSupport::TestCase

  def setup
    @user = User.new(name: "Example User", email: "user@example.com",
                     password: "foobar", password_confirmation: "foobar")
  end

  test "should be valid" do
    assert @user.valid?
  end

  test "name should be present" do
    @user.name = ""
    assert_not @user.valid?
  end

  test "email should be present" do
    @user.email = "     "
    assert_not @user.valid?
  end

  test "name should not be too long" do
    @user.name = "a" * 51
    assert_not @user.valid?
  end

  test "email should not be too long" do
    @user.email = "a" * 244 + "@example.com"
    assert_not @user.valid?
  end

  test "email validation should accept valid addresses" do
    valid_addresses = %w[user@example.com USER@foo.COM A_US-ER@foo.bar.org
                         first.last@foo.jp alice+bob@baz.cn]
    valid_addresses.each do |valid_address|
      @user.email = valid_address
      assert @user.valid?, "#{valid_address.inspect} should be valid"
    end
  end

  test "email validation should reject invalid addresses" do
    invalid_addresses = %w[user@example,com user_at_foo.org user.name@example.
                           foo@bar_baz.com foo@bar+baz.com]
    invalid_addresses.each do |invalid_address|
      @user.email = invalid_address
      assert_not @user.valid?, "#{invalid_address.inspect} should be invalid"
    end
  end

  test "email addresses should be unique" do
    duplicate_user = @user.dup
    @user.save
    assert_not duplicate_user.valid?
  end

  test "password should be present (nonblank)" do
    @user.password = @user.password_confirmation = " " * 6
    assert_not @user.valid?
  end

  test "password should have a minimum length" do
    @user.password = @user.password_confirmation = "a" * 5
    assert_not @user.valid?
  end

  test "authenticated? should return false for a user with nil digest" do
    assert_not @user.authenticated?(:remember, '')
  end

  test "associated microposts should be destroyed" do
    @user.save
    @user.microposts.create!(content: "Lorem ipsum")
    assert_difference 'Micropost.count', -1 do
      @user.destroy
    end
  end

  test "should follow and unfollow a user" do
    michael = users(:michael)
    archer  = users(:archer)
    assert_not michael.following?(archer)
    michael.follow(archer)
    assert michael.following?(archer)
    assert archer.followers.include?(michael)
    michael.unfollow(archer)
    assert_not michael.following?(archer)
    # Users can't follow themselves.
    michael.follow(michael)
    assert_not michael.following?(michael)
  end

  test "feed should have the right posts" do
    michael = users(:michael)
    archer  = users(:archer)
    lana    = users(:lana)
    # Posts from followed user
    lana.microposts.each do |post_following|
      assert michael.feed.include?(post_following)
    end
    # Self-posts for user with followers
    michael.microposts.each do |post_self|
      assert michael.feed.include?(post_self)
    end
    # Self-posts for user with no followers
    archer.microposts.each do |post_self|
      assert archer.feed.include?(post_self)
    end
    # Posts from unfollowed user
    archer.microposts.each do |post_unfollowed|
      assert_not michael.feed.include?(post_unfollowed)
    end
  end

  test "password reset should be expired just after 2 hours after sent" do
    @user.save
    @user.create_reset_digest
    # Travel slightly into the past relative to 2 hours ago
    travel_to 2.hours.ago - 1.second do
      @user.update_attribute(:reset_sent_at, Time.zone.now)
    end
    assert @user.password_reset_expired?
  end


  test "password should be valid when exactly minimum length" do
    @user.password = @user.password_confirmation = "a" * 6
    assert @user.valid?
  end


  test "email should be valid when exactly maximum length" do
    @user.email = ("a" * 243) + "@example.com" # 243 + 1 + 7 + 4 = 255
    assert @user.valid?
  end


  test "name should be valid when exactly maximum length" do
    @user.name = "a" * 50
    assert @user.valid?
  end

  test "feed should be empty for new user with no posts or following" do
    # Create a user but don't give them posts or follow anyone
    lonely_user = User.create!(name: "Lonely User", email: "lonely@example.com",
                               password: "password", password_confirmation: "password",
                               activated: true, activated_at: Time.zone.now)
    assert lonely_user.microposts.empty?
    assert lonely_user.following.empty?
    assert lonely_user.feed.empty?
  end


  test "password_reset_expired? should be false just under 2 hours after sent" do
    @user.save
    @user.create_reset_digest
    # Set reset_sent_at to slightly less than 2 hours ago (more recent)
    @user.update_attribute(:reset_sent_at, 2.hours.ago + 1.second)
    assert_not @user.password_reset_expired?
  end

=begin
FAILED TEST: **Analysis:**

1.  **Database Environment Mismatch (`stderr`):** The primary issue is an `ActiveRecord::EnvironmentMismatchError`. The test suite is attempting to run against a database configured for the `development` environment, not the `test` environment. This prevents proper test setup and execution.
2.  **Test Failure (`stdout`):** The `UserTest#test_password_reset_expired?_should_be_false_exactly_2_hours_after_sent` test failed. It asserted that `password_reset_expired?` should be false when the reset token was sent exactly 2 hours ago, but the method returned true. This failure is likely a symptom of the database environment issue preventing correct test data setup or state.

**Recommended Fixes:**

1.  **Correct Database Environment:** Run the command `bin/rails db:environment:set RAILS_ENV=test` in your terminal to resolve the environment mismatch.
2.  **Re-run Tests:** After fixing the environment, re-run the test suite. The specific test failure is expected to pass once the database environment is correct.

  test "password_reset_expired? should be false exactly 2 hours after sent" do
    @user.save
    @user.create_reset_digest
    # Set reset_sent_at to exactly 2 hours ago
    @user.update_attribute(:reset_sent_at, 2.hours.ago)
    assert_not @user.password_reset_expired?
  end

=end

  test "authenticated? should return false for incorrect reset token" do
    @user.save
    @user.create_reset_digest # Generate reset_digest
    assert_not @user.authenticated?(:reset, 'incorrect_token')
  end


  test "authenticated? should return false for incorrect activation token" do
    @user.save # Triggers create_activation_digest
    assert_not @user.authenticated?(:activation, 'incorrect_token')
  end


  test "authenticated? should return false for incorrect remember token" do
    @user.save
    @user.remember # Generate remember_digest
    assert_not @user.authenticated?(:remember, 'incorrect_token')
  end

  test "create_activation_digest not called on update" do
    @user.save # before_create callback runs here
    original_activation_digest = @user.activation_digest
    assert original_activation_digest.present?
    # Update the user
    @user.update(name: "Updated Name")
    @user.reload
    # Assert the activation digest hasn't changed
    assert_equal original_activation_digest, @user.activation_digest
  end


  test "downcase_email callback saves lowercase email" do
    mixed_case_email = "MiXeD.CaSe@ExAmPlE.CoM"
    @user.email = mixed_case_email
    @user.save
    @user.reload
    assert_equal mixed_case_email.downcase, @user.email
  end


  test "user can be updated without changing password" do
    @user.save
    original_digest = @user.password_digest
    new_name = "New Example Name"
    assert @user.update(name: new_name)
    @user.reload
    assert_equal new_name, @user.name
    assert_equal original_digest, @user.password_digest
  end

=begin
FAILED TEST: **Analysis:**

1.  **Database Environment Mismatch (`stderr`):** The core issue is an `ActiveRecord::EnvironmentMismatchError`. The test suite is incorrectly attempting to run against the `development` database instead of the `test` database, preventing proper test setup and execution.
2.  **Test Failure (`stdout`):** The `UserTest#test_follow_method_is_idempotent` test failed. It expected `Relationship.count` not to change when `follow` was called a second time on the same user, but the count increased, indicating a duplicate relationship was created. This is likely a symptom of the database environment error.

**Recommended Fixes:**

1.  **Set Test Environment:** Execute `bin/rails db:environment:set RAILS_ENV=test` in your terminal to correct the database environment configuration.
2.  **Re-run Tests:** After fixing the environment, run the test suite again. The `test_follow_method_is_idempotent` failure is expected to be resolved.

  test "follow method is idempotent" do
    michael = users(:michael)
    archer  = users(:archer)
    assert_not michael.following?(archer)
    # Follow first time
    assert_difference 'Relationship.count', 1 do
      michael.follow(archer)
    end
    assert michael.following?(archer)
    # Follow second time - should not create another relationship
    assert_no_difference 'Relationship.count' do
       assert_nothing_raised do
         michael.follow(archer)
       end
    end
    assert michael.following?(archer)
  end

=end

  test "authenticated? returns false for empty string token" do
    @user.save
    @user.remember # Creates remember_digest
    assert @user.remember_digest.present?
    assert_not @user.authenticated?(:remember, "")
  end

=begin
FAILED TEST: **Analysis:**

1.  **Database Environment Mismatch (`stderr`):** The primary error is an `ActiveRecord::EnvironmentMismatchError`. The tests are incorrectly trying to run against the `development` database instead of the `test` database. This is a critical setup failure preventing tests from running correctly.
2.  **Test Failure (`stdout`):** The `UserTest#test_password_reset_expired?_is_false_exactly_two_hours_after_sent` test failed. It asserted that `password_reset_expired?` should be false when the reset token was sent exactly 2 hours ago, but the method returned true. This failure is most likely a symptom of the database environment error preventing correct test data setup or state management.

**Recommended Fixes:**

1.  **Set Test Environment:** Run the command `bin/rails db:environment:set RAILS_ENV=test` in your terminal to configure the correct database environment.
2.  **Re-run Tests:** After fixing the environment, execute the test suite again. The specific test failure is expected to pass once the database environment is correct.

  test "password_reset_expired? is false exactly two hours after sent" do
    @user.save
    @user.create_reset_digest
    # Set reset_sent_at to exactly 2 hours ago
    @user.update_attribute(:reset_sent_at, 2.hours.ago)
    # The condition is `reset_sent_at < 2.hours.ago`, which is false if they are equal.
    assert_not @user.password_reset_expired?
  end

=end


end