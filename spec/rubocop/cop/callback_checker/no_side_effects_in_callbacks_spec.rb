# frozen_string_literal: true

require "spec_helper"

RSpec.describe RuboCop::Cop::CallbackChecker::NoSideEffectsInCallbacks, :config do
  describe "callbacks that should NOT register offenses" do
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

    it "does not register an offense for internal method calls in a callback" do
      expect_no_offenses(<<~RUBY)
        class User < ApplicationRecord
          before_save :sanitize_name

          def sanitize_name
            self.name = name.strip
            self.email = email.downcase
          end
        end
      RUBY
    end

    it "does not register an offense for internal logic in a block callback" do
      expect_no_offenses(<<~RUBY)
        class User < ApplicationRecord
          before_save do
            self.name = name.strip
          end
        end
      RUBY
    end

    it "does not register an offense in after_commit callback" do
      expect_no_offenses(<<~RUBY)
        class User < ApplicationRecord
          after_commit :send_notification

          def send_notification
            UserMailer.deliver_later
          end
        end
      RUBY
    end

    it "does not register an offense in after_create_commit callback" do
      expect_no_offenses(<<~RUBY)
        class User < ApplicationRecord
          after_create_commit do
            UserMailer.deliver_later
          end
        end
      RUBY
    end

    it "does not register an offense when method definition is not found" do
      expect_no_offenses(<<~RUBY)
        class User < ApplicationRecord
          before_save :nonexistent_method
        end
      RUBY
    end
  end

  describe "block form callbacks" do
    it "registers an offense when calling a background job in before_save block" do
      expect_offense(<<~RUBY)
        class User < ApplicationRecord
          before_save do
            UserMailer.deliver_later
            ^^^^^^^^^^^^^^^^^^^^^^^^ Avoid side effects (API calls, mailers, background jobs, or modifying other records) in before_save. Use `after_commit` instead.
          end
        end
      RUBY
    end

    it "registers an offense in before_validation block" do
      expect_offense(<<~RUBY)
        class User < ApplicationRecord
          before_validation do
            RestClient.save!('http://example.com', {data: 'test'})
            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Avoid side effects (API calls, mailers, background jobs, or modifying other records) in before_validation. Use `after_commit` instead.
          end
        end
      RUBY
    end

    it "registers an offense in after_save block" do
      expect_offense(<<~RUBY)
        class User < ApplicationRecord
          after_save do
            UserMailer.deliver_later
            ^^^^^^^^^^^^^^^^^^^^^^^^ Avoid side effects (API calls, mailers, background jobs, or modifying other records) in after_save. Use `after_commit` instead.
          end
        end
      RUBY
    end

    it "registers an offense in before_create block" do
      expect_offense(<<~RUBY)
        class User < ApplicationRecord
          before_create do
            UserMailer.deliver_later
            ^^^^^^^^^^^^^^^^^^^^^^^^ Avoid side effects (API calls, mailers, background jobs, or modifying other records) in before_create. Use `after_commit` instead.
          end
        end
      RUBY
    end

    it "registers an offense in before_update block" do
      expect_offense(<<~RUBY)
        class User < ApplicationRecord
          before_update do
            UserMailer.deliver_later
            ^^^^^^^^^^^^^^^^^^^^^^^^ Avoid side effects (API calls, mailers, background jobs, or modifying other records) in before_update. Use `after_commit` instead.
          end
        end
      RUBY
    end

    it "registers an offense in before_destroy block" do
      expect_offense(<<~RUBY)
        class User < ApplicationRecord
          before_destroy do
            UserMailer.deliver_later
            ^^^^^^^^^^^^^^^^^^^^^^^^ Avoid side effects (API calls, mailers, background jobs, or modifying other records) in before_destroy. Use `after_commit` instead.
          end
        end
      RUBY
    end
  end

  describe "symbol argument form callbacks" do
    it "registers an offense when calling a background job in before_save" do
      expect_offense(<<~RUBY)
        class User < ApplicationRecord
          before_save :send_notification

          def send_notification
            UserMailer.deliver_later
            ^^^^^^^^^^^^^^^^^^^^^^^^ Avoid side effects (API calls, mailers, background jobs, or modifying other records) in before_save. Use `after_commit` instead.
          end
        end
      RUBY
    end

    it "registers an offense for symbol callback in before_create" do
      expect_offense(<<~RUBY)
        class User < ApplicationRecord
          before_create :do_stuff

          def do_stuff
            UserMailer.deliver_later
            ^^^^^^^^^^^^^^^^^^^^^^^^ Avoid side effects (API calls, mailers, background jobs, or modifying other records) in before_create. Use `after_commit` instead.
          end
        end
      RUBY
    end
  end

  describe "external library calls" do
    it "registers an offense for RestClient calls" do
      expect_offense(<<~RUBY)
        class User < ApplicationRecord
          before_save do
            RestClient.get('http://example.com')
            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Avoid side effects (API calls, mailers, background jobs, or modifying other records) in before_save. Use `after_commit` instead.
          end
        end
      RUBY
    end

    it "registers an offense for Faraday calls" do
      expect_offense(<<~RUBY)
        class User < ApplicationRecord
          before_save do
            Faraday.get('http://example.com')
            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Avoid side effects (API calls, mailers, background jobs, or modifying other records) in before_save. Use `after_commit` instead.
          end
        end
      RUBY
    end

    it "registers an offense for HTTParty calls" do
      expect_offense(<<~RUBY)
        class User < ApplicationRecord
          before_save do
            HTTParty.get('http://example.com')
            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Avoid side effects (API calls, mailers, background jobs, or modifying other records) in before_save. Use `after_commit` instead.
          end
        end
      RUBY
    end

    it "registers an offense for Net calls" do
      expect_offense(<<~RUBY)
        class User < ApplicationRecord
          before_save do
            Net.start('example.com')
            ^^^^^^^^^^^^^^^^^^^^^^^^ Avoid side effects (API calls, mailers, background jobs, or modifying other records) in before_save. Use `after_commit` instead.
          end
        end
      RUBY
    end

    it "registers an offense for Sidekiq calls" do
      expect_offense(<<~RUBY)
        class User < ApplicationRecord
          before_save do
            Sidekiq.enqueue(SomeWorker)
            ^^^^^^^^^^^^^^^^^^^^^^^^^^^ Avoid side effects (API calls, mailers, background jobs, or modifying other records) in before_save. Use `after_commit` instead.
          end
        end
      RUBY
    end

    it "registers an offense for ActionCable calls" do
      expect_offense(<<~RUBY)
        class User < ApplicationRecord
          before_save do
            ActionCable.broadcast('channel', data)
            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Avoid side effects (API calls, mailers, background jobs, or modifying other records) in before_save. Use `after_commit` instead.
          end
        end
      RUBY
    end
  end

  describe "async delivery methods" do
    it "registers an offense for deliver_later" do
      expect_offense(<<~RUBY)
        class User < ApplicationRecord
          before_save do
            UserMailer.deliver_later
            ^^^^^^^^^^^^^^^^^^^^^^^^ Avoid side effects (API calls, mailers, background jobs, or modifying other records) in before_save. Use `after_commit` instead.
          end
        end
      RUBY
    end

    it "registers an offense for perform_later" do
      expect_offense(<<~RUBY)
        class User < ApplicationRecord
          before_save do
            SomeJob.perform_later
            ^^^^^^^^^^^^^^^^^^^^^ Avoid side effects (API calls, mailers, background jobs, or modifying other records) in before_save. Use `after_commit` instead.
          end
        end
      RUBY
    end

    it "registers an offense for broadcast_later" do
      expect_offense(<<~RUBY)
        class User < ApplicationRecord
          before_save do
            SomeChannel.broadcast_later
            ^^^^^^^^^^^^^^^^^^^^^^^^^^^ Avoid side effects (API calls, mailers, background jobs, or modifying other records) in before_save. Use `after_commit` instead.
          end
        end
      RUBY
    end
  end

  describe "side effect persistence on other objects" do
    it "registers an offense for save on a constant" do
      expect_offense(<<~RUBY)
        class User < ApplicationRecord
          before_save do
            OtherRecord.save
            ^^^^^^^^^^^^^^^^ Avoid side effects (API calls, mailers, background jobs, or modifying other records) in before_save. Use `after_commit` instead.
          end
        end
      RUBY
    end

    it "registers an offense for save! on a local variable" do
      expect_offense(<<~RUBY)
        class User < ApplicationRecord
          before_save do
            record = OtherRecord.new
            record.save!
            ^^^^^^^^^^^^ Avoid side effects (API calls, mailers, background jobs, or modifying other records) in before_save. Use `after_commit` instead.
          end
        end
      RUBY
    end

    it "registers an offense for update on an association" do
      expect_offense(<<~RUBY)
        class User < ApplicationRecord
          before_save do
            profile.update(name: 'test')
            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Avoid side effects (API calls, mailers, background jobs, or modifying other records) in before_save. Use `after_commit` instead.
          end
        end
      RUBY
    end

    it "registers an offense for update! on an association" do
      expect_offense(<<~RUBY)
        class User < ApplicationRecord
          before_save do
            profile.update!(name: 'test')
            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Avoid side effects (API calls, mailers, background jobs, or modifying other records) in before_save. Use `after_commit` instead.
          end
        end
      RUBY
    end

    it "registers an offense for destroy on an association" do
      expect_offense(<<~RUBY)
        class User < ApplicationRecord
          before_save do
            profile.destroy
            ^^^^^^^^^^^^^^^ Avoid side effects (API calls, mailers, background jobs, or modifying other records) in before_save. Use `after_commit` instead.
          end
        end
      RUBY
    end

    it "registers an offense for destroy! on an association" do
      expect_offense(<<~RUBY)
        class User < ApplicationRecord
          before_save do
            profile.destroy!
            ^^^^^^^^^^^^^^^^ Avoid side effects (API calls, mailers, background jobs, or modifying other records) in before_save. Use `after_commit` instead.
          end
        end
      RUBY
    end

    it "registers an offense for create on a constant" do
      expect_offense(<<~RUBY)
        class User < ApplicationRecord
          before_save do
            AuditLog.create(message: 'changed')
            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Avoid side effects (API calls, mailers, background jobs, or modifying other records) in before_save. Use `after_commit` instead.
          end
        end
      RUBY
    end

    it "registers an offense for create! on a constant" do
      expect_offense(<<~RUBY)
        class User < ApplicationRecord
          before_save do
            AuditLog.create!(message: 'changed')
            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Avoid side effects (API calls, mailers, background jobs, or modifying other records) in before_save. Use `after_commit` instead.
          end
        end
      RUBY
    end
  end

  describe "multiple offenses" do
    it "registers multiple offenses in the same callback" do # rubocop:disable RSpec/ExampleLength
      expect_offense(<<~RUBY)
        class User < ApplicationRecord
          before_save do
            UserMailer.deliver_later
            ^^^^^^^^^^^^^^^^^^^^^^^^ Avoid side effects (API calls, mailers, background jobs, or modifying other records) in before_save. Use `after_commit` instead.
            SomeJob.perform_later
            ^^^^^^^^^^^^^^^^^^^^^ Avoid side effects (API calls, mailers, background jobs, or modifying other records) in before_save. Use `after_commit` instead.
          end
        end
      RUBY
    end

    it "registers offenses across multiple callbacks" do # rubocop:disable RSpec/ExampleLength
      expect_offense(<<~RUBY)
        class User < ApplicationRecord
          before_create :do_stuff

          before_save do
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
end
