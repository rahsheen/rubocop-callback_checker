# frozen_string_literal: true

RSpec.describe RuboCop::Cop::CallbackChecker::AttributeAssignmentOnly, :config do
  let(:config) do
    RuboCop::Config.new(
      'CallbackChecker/AttributeAssignmentOnly' => { 'Enabled' => true },
      'CallbackChecker/AvoidSelfPersistence' => { 'Enabled' => false },
      'CallbackChecker/NoSideEffectsInCallbacks' => { 'Enabled' => false }
    )
  end

  context 'when using update in before_save' do
    it 'registers an offense' do
      expect_offense(<<~RUBY)
        class User < ApplicationRecord
          before_save :normalize_data

          def normalize_data
            update(name: name.strip)
            ^^^^^^^^^^^^^^^^^^^^^^^^ Use attribute assignment (`self.name = value`) instead of `update` in `before_save`. The object will be persisted automatically after the callback completes.
          end
        end
      RUBY
    end
  end

  context 'when using self.update in before_validation' do
    it 'registers an offense' do
      expect_offense(<<~RUBY)
        class User < ApplicationRecord
          before_validation :set_defaults

          def set_defaults
            self.update(status: 'pending')
            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Use attribute assignment (`self.status = value`) instead of `update` in `before_validation`. The object will be persisted automatically after the callback completes.
          end
        end
      RUBY
    end
  end

  context 'when using update! in before_create' do
    it 'registers an offense' do
      expect_offense(<<~RUBY)
        class User < ApplicationRecord
          before_create :setup

          def setup
            update!(activated: true)
            ^^^^^^^^^^^^^^^^^^^^^^^^ Use attribute assignment (`self.activated = value`) instead of `update!` in `before_create`. The object will be persisted automatically after the callback completes.
          end
        end
      RUBY
    end
  end

  context 'when using update_columns in before_save' do
    it 'registers an offense' do
      expect_offense(<<~RUBY)
        class User < ApplicationRecord
          before_save :set_token

          def set_token
            update_columns(token: generate_token)
            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Use attribute assignment (`self.token = value`) instead of `update_columns` in `before_save`. The object will be persisted automatically after the callback completes.
          end
        end
      RUBY
    end
  end

  context 'when using update_attribute in before_validation' do
    it 'registers an offense' do
      expect_offense(<<~RUBY)
        class User < ApplicationRecord
          before_validation { update_attribute(:name, name.strip) }
                              ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Use attribute assignment (`self.name = value`) instead of `update_attribute` in `before_validation`. The object will be persisted automatically after the callback completes.
        end
      RUBY
    end
  end

  context 'when using update_column in before_update callback' do
    it 'registers an offense' do
      expect_offense(<<~RUBY)
        class User < ApplicationRecord
          before_update :track_changes

          def track_changes
            update_column(:updated_by, current_user.id)
            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Use attribute assignment (`self.updated_by = value`) instead of `update_column` in `before_update`. The object will be persisted automatically after the callback completes.
          end
        end
      RUBY
    end
  end

  context 'when using update_attributes in before_save' do
    it 'registers an offense' do
      expect_offense(<<~RUBY)
        class User < ApplicationRecord
          before_save :normalize

          def normalize
            update_attributes(name: name.strip, email: email.downcase)
            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Use attribute assignment (`self.name = value`) instead of `update_attributes` in `before_save`. The object will be persisted automatically after the callback completes.
          end
        end
      RUBY
    end
  end

  context 'when using update_attributes! in before_validation' do
    it 'registers an offense' do
      expect_offense(<<~RUBY)
        class User < ApplicationRecord
          before_validation :set_values

          def set_values
            update_attributes!(status: 'pending')
            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Use attribute assignment (`self.status = value`) instead of `update_attributes!` in `before_validation`. The object will be persisted automatically after the callback completes.
          end
        end
      RUBY
    end
  end

  context 'when using attribute assignment in before_save' do
    it 'does not register an offense' do
      expect_no_offenses(<<~RUBY)
        class User < ApplicationRecord
          before_save :normalize_data

          def normalize_data
            self.name = name.strip
            self.email = email.downcase
          end
        end
      RUBY
    end
  end

  context 'when using update in after_save' do
    it 'does not register an offense' do
      expect_no_offenses(<<~RUBY)
        class User < ApplicationRecord
          after_save :update_related

          def update_related
            update(last_modified: Time.current)
          end
        end
      RUBY
    end
  end

  context 'when using update in after_create' do
    it 'does not register an offense' do
      expect_no_offenses(<<~RUBY)
        class User < ApplicationRecord
          after_create :finalize

          def finalize
            update(created_via: 'api')
          end
        end
      RUBY
    end
  end

  context 'when using update in after_commit' do
    it 'does not register an offense' do
      expect_no_offenses(<<~RUBY)
        class User < ApplicationRecord
          after_commit :finalize

          def finalize
            update(finalized: true)
          end
        end
      RUBY
    end
  end

  context 'when using update in around_save' do
    it 'does not register an offense' do
      expect_no_offenses(<<~RUBY)
        class User < ApplicationRecord
          around_save :wrap_save

          def wrap_save
            update(processing: true)
            yield
          end
        end
      RUBY
    end
  end

  context 'when updating another object in before_save' do
    it 'does not register an offense' do
      expect_no_offenses(<<~RUBY)
        class User < ApplicationRecord
          before_save :update_profile

          def update_profile
            profile.update(name: full_name)
          end
        end
      RUBY
    end
  end

  context 'when using lambda callback with update' do
    it 'registers an offense' do
      expect_offense(<<~RUBY)
        class User < ApplicationRecord
          before_save -> { update(name: name.strip) }
                           ^^^^^^^^^^^^^^^^^^^^^^^^ Use attribute assignment (`self.name = value`) instead of `update` in `before_save`. The object will be persisted automatically after the callback completes.
        end
      RUBY
    end
  end

  context 'when using proc callback with update' do
    it 'registers an offense' do
      expect_offense(<<~RUBY)
        class User < ApplicationRecord
          before_validation proc { update!(status: 'pending') }
                                   ^^^^^^^^^^^^^^^^^^^^^^^^^^^ Use attribute assignment (`self.status = value`) instead of `update!` in `before_validation`. The object will be persisted automatically after the callback completes.
        end
      RUBY
    end
  end

  context 'when method is not a callback' do
    it 'does not register an offense' do
      expect_no_offenses(<<~RUBY)
        class User < ApplicationRecord
          def some_method
            update(name: 'test')
          end
        end
      RUBY
    end
  end

  context 'when using multiple persistence calls in one callback' do
    it 'registers multiple offenses' do
      expect_offense(<<~RUBY)
        class User < ApplicationRecord
          before_save :process

          def process
            update(name: name.strip)
            ^^^^^^^^^^^^^^^^^^^^^^^^ Use attribute assignment (`self.name = value`) instead of `update` in `before_save`. The object will be persisted automatically after the callback completes.
            update_columns(email: email.downcase)
            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Use attribute assignment (`self.email = value`) instead of `update_columns` in `before_save`. The object will be persisted automatically after the callback completes.
          end
        end
      RUBY
    end
  end

  context 'when using conditional logic' do
    it 'registers an offense inside conditional' do
      expect_offense(<<~RUBY)
        class User < ApplicationRecord
          before_save :conditional_update

          def conditional_update
            if name_changed?
              update(name: name.strip)
              ^^^^^^^^^^^^^^^^^^^^^^^^ Use attribute assignment (`self.name = value`) instead of `update` in `before_save`. The object will be persisted automatically after the callback completes.
            end
          end
        end
      RUBY
    end
  end

  context 'when using nested conditionals' do
    it 'registers an offense deep in logic' do
      expect_offense(<<~RUBY)
        class User < ApplicationRecord
          before_validation :complex_logic

          def complex_logic
            if active?
              if name.present?
                update(name: name.strip)
                ^^^^^^^^^^^^^^^^^^^^^^^^ Use attribute assignment (`self.name = value`) instead of `update` in `before_validation`. The object will be persisted automatically after the callback completes.
              end
            end
          end
        end
      RUBY
    end
  end

  context 'when update has no arguments' do
    it 'registers an offense with generic message' do
      expect_offense(<<~RUBY)
        class User < ApplicationRecord
          before_save :do_update

          def do_update
            update
            ^^^^^^ Use attribute assignment (`self.attribute = value`) instead of `update` in `before_save`. The object will be persisted automatically after the callback completes.
          end
        end
      RUBY
    end
  end

  context 'when update has non-hash argument' do
    it 'registers an offense with generic message' do
      expect_offense(<<~RUBY)
        class User < ApplicationRecord
          before_save :do_update

          def do_update
            update(attrs)
            ^^^^^^^^^^^^^ Use attribute assignment (`self.attribute = value`) instead of `update` in `before_save`. The object will be persisted automatically after the callback completes.
          end
        end
      RUBY
    end
  end

  context 'when before_destroy callback uses update' do
    it 'does not register an offense' do
      expect_no_offenses(<<~RUBY)
        class User < ApplicationRecord
          before_destroy :mark_deleted

          def mark_deleted
            update(deleted: true)
          end
        end
      RUBY
    end
  end
end
