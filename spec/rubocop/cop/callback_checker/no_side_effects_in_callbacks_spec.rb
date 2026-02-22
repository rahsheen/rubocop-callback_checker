# frozen_string_literal: true

# In spec/rubocop/cop/callback_checker/no_side_effects_in_callbacks_spec.rb

require "spec_helper"

RSpec.describe RuboCop::Cop::CallbackChecker::NoSideEffectsInCallbacks, :config do
  # Code that is CORRECT (should not be flagged)
  it "does not register an offense when logic is purely internal" do
    expect_no_offenses(<<~RUBY)
      class User < ApplicationRecord
        before_save :sanitize_name
        def sanitize_name
          self.name = name.strip
        end
      end
    RUBY
  end

  context "when callback is defined as a lambda" do
    it "registers an offense when calling a background job in before_save" do
      expect_offense(<<~RUBY)
        class User < ApplicationRecord
          before_create :do_stuff

          before_save do
            # Side effect indicator: perform_later
            UserMailer.deliver_later
            ^^^^^^^^^^^^^^^^^^^^^^^^ Avoid side effects (API calls, mailers, background jobs, or modifying other records) in before_save. Use `after_commit` instead.
          end

          after_save do
            pp "butts"
          end

          def do_stuff
            UserMailer.deliver_later
            ^^^^^^^^^^^^^^^^^^^^^^^^ Avoid side effects (API calls, mailers, background jobs, or modifying other records) in before_create. Use `after_commit` instead.
          end
        end
      RUBY
    end
  end

  it "registers an offense when calling a background job in before_save" do
    expect_offense(<<~RUBY)
      class User < ApplicationRecord
        before_save :send_notification

        def send_notification
          # Side effect indicator: perform_later
          UserMailer.deliver_later
          ^^^^^^^^^^^^^^^^^^^^^^^^ #{format(described_class::MSG, callback: :before_save)}
        end
      end
    RUBY
  end

  it "registers an offense for any method call in a callback" do
    expect_offense(<<~RUBY)
      class User < ApplicationRecord
        before_save :sanitize_name

        def sanitize_name
          some_method_call
          ^^^^^^^^^^^^^^^^ #{format(described_class::MSG, callback: :before_save)}
        end
      end
    RUBY
  end

  it "registers an offense for any method call in a block callback" do
    expect_offense(<<~RUBY)
      class User < ApplicationRecord
        before_save do
          some_method_call
          ^^^^^^^^^^^^^^^^ #{format(described_class::MSG, callback: :before_save)}
        end
      end
    RUBY
  end
end
