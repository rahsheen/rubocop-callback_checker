# frozen_string_literal: true

RSpec.describe RuboCop::Cop::CallbackChecker::ConditionalStyle, :config do
  let(:config) do
    RuboCop::Config.new(
      'CallbackChecker/ConditionalStyle' => { 'Enabled' => true },
      'CallbackChecker/AvoidSelfPersistence' => { 'Enabled' => false },
      'CallbackChecker/NoSideEffectsInCallbacks' => { 'Enabled' => false },
      'CallbackChecker/AttributeAssignmentOnly' => { 'Enabled' => false },
      'CallbackChecker/CallbackMethodLength' => { 'Enabled' => false }
    )
  end

  context 'when using lambda for if: conditional' do
    it 'registers an offense' do
      expect_offense(<<~RUBY)
        class User < ApplicationRecord
          before_save :do_thing, if: -> { status == 'active' }
                                     ^^^^^^^^^^^^^^^^^^^^^^^^^ Use a named method instead of a proc/lambda for callback conditionals. Extract the logic to a private method with a descriptive name.
        end
      RUBY
    end
  end

  context 'when using lambda for unless: conditional' do
    it 'registers an offense' do
      expect_offense(<<~RUBY)
        class User < ApplicationRecord
          after_create :notify, unless: -> { Rails.env.test? }
                                        ^^^^^^^^^^^^^^^^^^^^^^ Use a named method instead of a proc/lambda for callback conditionals. Extract the logic to a private method with a descriptive name.
        end
      RUBY
    end
  end

  context 'when using proc for if: conditional' do
    it 'registers an offense' do
      expect_offense(<<~RUBY)
        class User < ApplicationRecord
          before_save :check, if: proc { active? && !deleted? }
                                  ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Use a named method instead of a proc/lambda for callback conditionals. Extract the logic to a private method with a descriptive name.
        end
      RUBY
    end
  end

  context 'when using string for if: conditional' do
    it 'registers an offense' do
      expect_offense(<<~RUBY)
        class User < ApplicationRecord
          before_validation :check, if: "status == 'active'"
                                        ^^^^^^^^^^^^^^^^^^^^ Use a named method instead of a string for callback conditionals. Extract the logic to a private method with a descriptive name.
        end
      RUBY
    end
  end

  context 'when using string for unless: conditional' do
    it 'registers an offense' do
      expect_offense(<<~RUBY)
        class User < ApplicationRecord
          after_save :log, unless: "Rails.env.production?"
                                   ^^^^^^^^^^^^^^^^^^^^^^^^ Use a named method instead of a string for callback conditionals. Extract the logic to a private method with a descriptive name.
        end
      RUBY
    end
  end

  context 'when using complex lambda' do
    it 'registers an offense' do
      expect_offense(<<~RUBY)
        class User < ApplicationRecord
          before_save :process, if: -> { status == 'active' && !deleted? && verified? }
                                    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Use a named method instead of a proc/lambda for callback conditionals. Extract the logic to a private method with a descriptive name.
        end
      RUBY
    end
  end

  context 'when using symbol for if: conditional' do
    it 'does not register an offense' do
      expect_no_offenses(<<~RUBY)
        class User < ApplicationRecord
          before_save :do_thing, if: :active?
        end
      RUBY
    end
  end

  context 'when using symbol for unless: conditional' do
    it 'does not register an offense' do
      expect_no_offenses(<<~RUBY)
        class User < ApplicationRecord
          after_create :notify, unless: :test_environment?
        end
      RUBY
    end
  end

  context 'when using both if and unless with symbols' do
    it 'does not register an offense' do
      expect_no_offenses(<<~RUBY)
        class User < ApplicationRecord
          before_save :process, if: :active?, unless: :deleted?
        end
      RUBY
    end
  end

  context 'when using both if and unless with mixed styles' do
    it 'registers an offense for the proc only' do
      expect_offense(<<~RUBY)
        class User < ApplicationRecord
          before_save :process, if: -> { active? }, unless: :deleted?
                                    ^^^^^^^^^^^^^^ Use a named method instead of a proc/lambda for callback conditionals. Extract the logic to a private method with a descriptive name.
        end
      RUBY
    end
  end

  context 'when callback has no conditionals' do
    it 'does not register an offense' do
      expect_no_offenses(<<~RUBY)
        class User < ApplicationRecord
          before_save :normalize_fields
        end
      RUBY
    end
  end

  context 'when callback has other options but no conditionals' do
    it 'does not register an offense' do
      expect_no_offenses(<<~RUBY)
        class User < ApplicationRecord
          after_commit :notify, on: :create
        end
      RUBY
    end
  end

  context 'when using lambda in before_validation' do
    it 'registers an offense' do
      expect_offense(<<~RUBY)
        class User < ApplicationRecord
          before_validation :check_email, if: -> { email_changed? }
                                              ^^^^^^^^^^^^^^^^^^^^^ Use a named method instead of a proc/lambda for callback conditionals. Extract the logic to a private method with a descriptive name.
        end
      RUBY
    end
  end

  context 'when using proc in after_commit' do
    it 'registers an offense' do
      expect_offense(<<~RUBY)
        class User < ApplicationRecord
          after_commit :send_notification, unless: proc { Rails.env.test? }
                                                   ^^^^^^^^^^^^^^^^^^^^^^^^ Use a named method instead of a proc/lambda for callback conditionals. Extract the logic to a private method with a descriptive name.
        end
      RUBY
    end
  end

  context 'when using lambda in around_save' do
    it 'registers an offense' do
      expect_offense(<<~RUBY)
        class User < ApplicationRecord
          around_save :wrap, if: -> { perform_wrapping? }
                                 ^^^^^^^^^^^^^^^^^^^^^^^^ Use a named method instead of a proc/lambda for callback conditionals. Extract the logic to a private method with a descriptive name.
        end
      RUBY
    end
  end

  context 'when using string in before_destroy' do
    it 'registers an offense' do
      expect_offense(<<~RUBY)
        class User < ApplicationRecord
          before_destroy :archive, if: "can_be_destroyed?"
                                       ^^^^^^^^^^^^^^^^^^^^ Use a named method instead of a string for callback conditionals. Extract the logic to a private method with a descriptive name.
        end
      RUBY
    end
  end

  context 'when multiple callbacks with different styles' do
    it 'registers offenses for procs/strings only' do
      expect_offense(<<~RUBY)
        class User < ApplicationRecord
          before_save :method_one, if: :active?
          after_save :method_two, if: -> { deleted? }
                                      ^^^^^^^^^^^^^^^ Use a named method instead of a proc/lambda for callback conditionals. Extract the logic to a private method with a descriptive name.
          before_create :method_three, unless: "Rails.env.test?"
                                               ^^^^^^^^^^^^^^^^^^ Use a named method instead of a string for callback conditionals. Extract the logic to a private method with a descriptive name.
        end
      RUBY
    end
  end

  context 'when callback uses block syntax with conditional' do
    it 'registers an offense for proc conditional' do
      expect_offense(<<~RUBY)
        class User < ApplicationRecord
          before_save if: -> { active? } do
                          ^^^^^^^^^^^^^^ Use a named method instead of a proc/lambda for callback conditionals. Extract the logic to a private method with a descriptive name.
            self.name = name.strip
          end
        end
      RUBY
    end
  end

  context 'when using lambda with multiline block' do
    it 'registers an offense' do
      expect_offense(<<~RUBY)
        class User < ApplicationRecord
          before_save :process, if: lambda {
                                    ^^^^^^^^ Use a named method instead of a proc/lambda for callback conditionals. Extract the logic to a private method with a descriptive name.
            status == 'active' && !deleted?
          }
        end
      RUBY
    end
  end

  context 'when non-callback method has lambda' do
    it 'does not register an offense' do
      expect_no_offenses(<<~RUBY)
        class User < ApplicationRecord
          def some_method(if: -> { true })
            # some logic
          end
        end
      RUBY
    end
  end
end
