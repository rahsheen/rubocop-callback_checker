# frozen_string_literal: true

RSpec.describe RuboCop::Cop::CallbackChecker::AvoidSelfPersistence, :config do
  let(:config) do
    RuboCop::Config.new(
      'CallbackChecker/AvoidSelfPersistence' => { 'Enabled' => true },
      'CallbackChecker/NoSideEffectsInCallbacks' => { 'Enabled' => false }
    )
  end

  context 'when using explicit self.save in callback method' do
    it 'registers an offense' do
      expect_offense(<<~RUBY)
        class User < ApplicationRecord
          after_save :activate_user

          def activate_user
            self.save
            ^^^^^^^^^ Avoid calling `save` on self within `after_save`. This can trigger infinite loops or run callbacks multiple times. Assign attributes directly instead: `self.attribute = value`.
          end
        end
      RUBY
    end
  end

  context 'when using implicit save in callback method' do
    it 'registers an offense' do
      expect_offense(<<~RUBY)
        class User < ApplicationRecord
          before_validation :set_defaults

          def set_defaults
            save
            ^^^^ Avoid calling `save` on self within `before_validation`. This can trigger infinite loops or run callbacks multiple times. Assign attributes directly instead: `self.attribute = value`.
          end
        end
      RUBY
    end
  end

  context 'when using update in callback block' do
    it 'registers an offense' do
      expect_offense(<<~RUBY)
        class User < ApplicationRecord
          after_create { update(status: 'active') }
                         ^^^^^^^^^^^^^^^^^^^^^^^^ Avoid calling `update` on self within `after_create`. This can trigger infinite loops or run callbacks multiple times. Assign attributes directly instead: `self.attribute = value`.
        end
      RUBY
    end
  end

  context 'when using self.update! in callback method' do
    it 'registers an offense' do
      expect_offense(<<~RUBY)
        class User < ApplicationRecord
          before_save :ensure_status

          def ensure_status
            self.update!(status: 'pending')
            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Avoid calling `update!` on self within `before_save`. This can trigger infinite loops or run callbacks multiple times. Assign attributes directly instead: `self.attribute = value`.
          end
        end
      RUBY
    end
  end

  context 'when using toggle! in callback' do
    it 'registers an offense' do
      expect_offense(<<~RUBY)
        class User < ApplicationRecord
          after_update :toggle_flag

          def toggle_flag
            toggle!(:active)
            ^^^^^^^^^^^^^^^^ Avoid calling `toggle!` on self within `after_update`. This can trigger infinite loops or run callbacks multiple times. Assign attributes directly instead: `self.attribute = value`.
          end
        end
      RUBY
    end
  end

  context 'when using increment! in callback' do
    it 'registers an offense' do
      expect_offense(<<~RUBY)
        class User < ApplicationRecord
          after_save :bump_counter

          def bump_counter
            increment!(:login_count)
            ^^^^^^^^^^^^^^^^^^^^^^^^ Avoid calling `increment!` on self within `after_save`. This can trigger infinite loops or run callbacks multiple times. Assign attributes directly instead: `self.attribute = value`.
          end
        end
      RUBY
    end
  end

  context 'when using update_column in callback' do
    it 'registers an offense' do
      expect_offense(<<~RUBY)
        class User < ApplicationRecord
          before_validation :set_token

          def set_token
            update_column(:token, generate_token)
            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Avoid calling `update_column` on self within `before_validation`. This can trigger infinite loops or run callbacks multiple times. Assign attributes directly instead: `self.attribute = value`.
          end
        end
      RUBY
    end
  end

  context 'when using touch in callback' do
    it 'registers an offense' do
      expect_offense(<<~RUBY)
        class User < ApplicationRecord
          after_create :touch_timestamp

          def touch_timestamp
            touch(:activated_at)
            ^^^^^^^^^^^^^^^^^^^^ Avoid calling `touch` on self within `after_create`. This can trigger infinite loops or run callbacks multiple times. Assign attributes directly instead: `self.attribute = value`.
          end
        end
      RUBY
    end
  end

  context 'when assigning attributes directly' do
    it 'does not register an offense' do
      expect_no_offenses(<<~RUBY)
        class User < ApplicationRecord
          after_save :activate_user

          def activate_user
            self.status = 'active'
            self.activated_at = Time.current
          end
        end
      RUBY
    end
  end

  context 'when calling save on another object' do
    it 'does not register an offense' do
      expect_no_offenses(<<~RUBY)
        class User < ApplicationRecord
          after_save :create_profile

          def create_profile
            profile = Profile.new(user: self)
            profile.save
          end
        end
      RUBY
    end
  end

  context 'when calling update on an association' do
    it 'does not register an offense' do
      expect_no_offenses(<<~RUBY)
        class User < ApplicationRecord
          after_save :update_profile

          def update_profile
            profile.update(name: full_name)
          end
        end
      RUBY
    end
  end

  context 'when using after_commit callback' do
    it 'does not register an offense for self.save' do
      expect_no_offenses(<<~RUBY)
        class User < ApplicationRecord
          after_commit :do_something

          def do_something
            self.save
          end
        end
      RUBY
    end
  end

  context 'when using multiple persistence methods in one callback' do
    it 'registers multiple offenses' do
      expect_offense(<<~RUBY)
        class User < ApplicationRecord
          after_save :process

          def process
            save
            ^^^^ Avoid calling `save` on self within `after_save`. This can trigger infinite loops or run callbacks multiple times. Assign attributes directly instead: `self.attribute = value`.
            update(status: 'done')
            ^^^^^^^^^^^^^^^^^^^^^^ Avoid calling `update` on self within `after_save`. This can trigger infinite loops or run callbacks multiple times. Assign attributes directly instead: `self.attribute = value`.
          end
        end
      RUBY
    end
  end

  context 'when using around callbacks' do
    it 'registers an offense for self persistence' do
      expect_offense(<<~RUBY)
        class User < ApplicationRecord
          around_save :wrap_save

          def wrap_save
            self.update!(processed: true)
            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Avoid calling `update!` on self within `around_save`. This can trigger infinite loops or run callbacks multiple times. Assign attributes directly instead: `self.attribute = value`.
            yield
          end
        end
      RUBY
    end
  end

  context 'when callback has conditional logic' do
    it 'registers an offense inside conditional' do
      expect_offense(<<~RUBY)
        class User < ApplicationRecord
          before_save :conditional_update

          def conditional_update
            if status_changed?
              self.save
              ^^^^^^^^^ Avoid calling `save` on self within `before_save`. This can trigger infinite loops or run callbacks multiple times. Assign attributes directly instead: `self.attribute = value`.
            end
          end
        end
      RUBY
    end
  end

  context 'when using lambda callback with self persistence' do
    it 'registers an offense' do
      expect_offense(<<~RUBY)
        class User < ApplicationRecord
          after_save -> { self.update!(status: 'done') }
                          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Avoid calling `update!` on self within `after_save`. This can trigger infinite loops or run callbacks multiple times. Assign attributes directly instead: `self.attribute = value`.
        end
      RUBY
    end
  end

  context 'when using proc callback with self persistence' do
    it 'registers an offense' do
      expect_offense(<<~RUBY)
        class User < ApplicationRecord
          before_validation proc { save! }
                                   ^^^^^^ Avoid calling `save!` on self within `before_validation`. This can trigger infinite loops or run callbacks multiple times. Assign attributes directly instead: `self.attribute = value`.
        end
      RUBY
    end
  end

  context 'when method is not a callback' do
    it 'does not register an offense' do
      expect_no_offenses(<<~RUBY)
        class User < ApplicationRecord
          def some_method
            self.save
          end
        end
      RUBY
    end
  end
end
