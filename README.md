# RuboCop::CallbackChecker

A collection of RuboCop cops to ensure your ActiveRecord callbacks are safe, performant, and maintainable.

Banning callbacks entirely is a blunt instrument that slows down development. This gem provides a "surgical" approach—allowing callbacks for internal state management while preventing the most common architectural "gotchas" like recursive loops, phantom API calls, and bloated models.

---

## Installation

Install the gem and add to the application's Gemfile by executing:

```bash
bundle add rubocop-callback_checker
```

If bundler is not being used to manage dependencies, install the gem by executing:

```bash
gem install rubocop-callback_checker
```

---

## Usage

In your `.rubocop.yml`, add the following:

```yaml
# Modern method (RuboCop 1.72+)
plugins:
  - rubocop-callback_checker

# Alternative method (older RuboCop versions)
require:
  - rubocop-callback_checker
```

You can then run RuboCop as usual:

```bash
bundle exec rubocop
```

The gem will automatically load all callback checker cops with their default configurations.

---

## Configuration

All cops are enabled by default with reasonable settings. You can customize them in your `.rubocop.yml`:

```yaml
plugins:
  - rubocop-callback_checker

CallbackChecker/CallbackMethodLength:
  Max: 10  # Default is 5

CallbackChecker/NoSideEffectsInCallbacks:
  Enabled: false  # Disable if needed
```

---

## Cops Included

### 1. `CallbackChecker/NoSideEffectsInCallbacks`

**Goal:** Prevent external side effects from running inside a database transaction.

If a side effect (like sending an email) triggers in an `after_save` but the transaction later rolls back, the email is sent for data that doesn't exist.

* **Bad:** Calling `UserMailer.welcome.deliver_now` in `after_create`.
* **Good:** Use `after_commit` or `after_create_commit`.

**Example:**

```ruby
# bad
class User < ApplicationRecord
  after_create { UserMailer.welcome(self).deliver_now }
end

# good
class User < ApplicationRecord
  after_create_commit { UserMailer.welcome(self).deliver_now }
end
```

---

### 2. `CallbackChecker/AvoidSelfPersistence`

**Goal:** Prevent infinite recursion and "Stack Level Too Deep" errors.

* **Bad:** Calling `self.save` or `update(status: 'active')` inside a `before_save`.
* **Good:** Assign attributes directly: `self.status = 'active'`.

**Example:**

```ruby
# bad
class User < ApplicationRecord
  before_save :activate
  
  def activate
    self.update(status: 'active')  # triggers before_save again!
  end
end

# good
class User < ApplicationRecord
  before_save :activate
  
  def activate
    self.status = 'active'  # will be saved automatically
  end
end
```

---

### 3. `CallbackChecker/AttributeAssignmentOnly`

**Goal:** Reduce unnecessary database I/O.

Callbacks that run "before" persistence should only modify the object's memory state, not trigger a secondary database write.

* **Bad:** `before_validation { update(attr: 'val') }`
* **Good:** `before_validation { self.attr = 'val' }`

**Example:**

```ruby
# bad
class User < ApplicationRecord
  before_save :normalize_email
  
  def normalize_email
    update(email: email.downcase)  # unnecessary extra query
  end
end

# good
class User < ApplicationRecord
  before_save :normalize_email
  
  def normalize_email
    self.email = email.downcase  # just modifies in memory
  end
end
```

---

### 4. `CallbackChecker/CallbackMethodLength`

**Goal:** Prevent "Fat Models" and maintain testability.

Callbacks should be "post-it notes," not "instruction manuals." If a callback method is too long, it should be moved to a Service Object.

* **Default Max:** 5 lines (configurable).

**Example:**

```ruby
# bad
class User < ApplicationRecord
  after_create :setup_account
  
  def setup_account
    # 20 lines of complex logic...
    create_default_settings
    send_welcome_email
    notify_admin
    create_billing_account
    # ...
  end
end

# good
class User < ApplicationRecord
  after_create_commit :setup_account
  
  def setup_account
    AccountSetupService.new(self).call
  end
end
```

---

### 5. `CallbackChecker/ConditionalStyle`

**Goal:** Improve readability and allow for easier debugging.

* **Bad:** `before_save :do_thing, if: -> { status == 'active' && !deleted? }`
* **Good:** `before_save :do_thing, if: :active_and_present?`

**Example:**

```ruby
# bad
class User < ApplicationRecord
  before_save :do_thing, if: -> { status == 'active' && !deleted? }
end

# good
class User < ApplicationRecord
  before_save :do_thing, if: :active_and_present?
  
  private
  
  def active_and_present?
    status == 'active' && !deleted?
  end
end
```

---

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/rahsheen/rubocop-callback_checker.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

---
