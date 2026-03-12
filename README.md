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
require:
  - rubocop-callback_checker

```

You can then run RuboCop as usual:

```bash
bundle exec rubocop

```

---

## Cops Included

### 1. `CallbackChecker/NoSideEffectsInCallbacks`

**Goal:** Prevent external side effects from running inside a database transaction.

If a side effect (like sending an email) triggers in an `after_save` but the transaction later rolls back, the email is sent for data that doesn't exist.

* **Bad:** Calling `UserMailer.welcome.deliver_now` in `after_create`.
* **Good:** Use `after_commit` or `after_create_commit`.

### 2. `CallbackChecker/NoSelfPersistence`

**Goal:** Prevent infinite recursion and "Stack Level Too Deep" errors.

* **Bad:** Calling `self.save` or `update(status: 'active')` inside a `before_save`.
* **Good:** Assign attributes directly: `self.status = 'active'`.

### 3. `CallbackChecker/AttributeAssignmentOnly`

**Goal:** Reduce unnecessary database I/O.

Callbacks that run "before" persistence should only modify the object's memory state, not trigger a secondary database write.

* **Bad:** `before_validation { update(attr: 'val') }`
* **Good:** `before_validation { self.attr = 'val' }`

### 4. `CallbackChecker/CallbackMethodLength`

**Goal:** Prevent "Fat Models" and maintain testability.

Callbacks should be "post-it notes," not "instruction manuals." If a callback method is too long, it should be moved to a Service Object.

* **Default Max:** 10 lines.

### 5. `CallbackChecker/SymbolicConditionals`

**Goal:** Improve readability and allow for easier debugging.

* **Bad:** `before_save :do_thing, if: -> { status == 'active' && !deleted? }`
* **Good:** `before_save :do_thing, if: :active_and_present?`

---

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`.

## Contributing

Bug reports and pull requests are welcome on GitHub at [https://github.com/](https://github.com/)[USERNAME]/rubocop-callback_checker.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

---

