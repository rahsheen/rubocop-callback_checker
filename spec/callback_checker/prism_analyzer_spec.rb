# frozen_string_literal: true

require 'spec_helper'
require_relative '../../lib/callback_checker/prism_analyzer'

RSpec.describe CallbackChecker::PrismAnalyzer do
  def analyze(source)
    described_class.analyze_source(source)
  end

  def expect_no_offenses(source)
    offenses = analyze(source)
    expect(offenses).to be_empty, "Expected no offenses but got: #{offenses.map { |o| o[:message] }.join(', ')}"
  end

  def expect_offense(source)
    offenses = analyze(source)
    expect(offenses).not_to be_empty, 'Expected offenses but got none'
    offenses
  end

  describe 'callbacks that should NOT register offenses' do
    it 'does not register an offense when logic is purely internal' do
      expect_no_offenses(<<~RUBY)
        class User < ApplicationRecord
          before_save :sanitize_name
          def sanitize_name
            self.name = name.strip
          end
        end
      RUBY
    end

    it 'does not register an offense for internal method calls in a callback' do
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

    it 'does not register an offense for internal logic in a block callback' do
      expect_no_offenses(<<~RUBY)
        class User < ApplicationRecord
          before_save do
            self.name = name.strip
          end
        end
      RUBY
    end

    it 'does not register an offense in after_commit callback' do
      expect_no_offenses(<<~RUBY)
        class User < ApplicationRecord
          after_commit :send_notification

          def send_notification
            UserMailer.deliver_later
          end
        end
      RUBY
    end

    it 'does not register an offense in after_create_commit callback' do
      expect_no_offenses(<<~RUBY)
        class User < ApplicationRecord
          after_create_commit do
            UserMailer.deliver_later
          end
        end
      RUBY
    end

    it 'does not register an offense when method definition is not found' do
      expect_no_offenses(<<~RUBY)
        class User < ApplicationRecord
          before_save :nonexistent_method
        end
      RUBY
    end
  end

  describe 'block form callbacks' do
    it 'registers an offense when calling a background job in before_save block' do
      offenses = expect_offense(<<~RUBY)
        class User < ApplicationRecord
          before_save do
            UserMailer.deliver_later
          end
        end
      RUBY
      expect(offenses.first[:message]).to include('before_save')
      expect(offenses.first[:message]).to include('after_commit')
    end

    it 'registers an offense in before_validation block' do
      offenses = expect_offense(<<~RUBY)
        class User < ApplicationRecord
          before_validation do
            RestClient.save!('http://example.com', {data: 'test'})
          end
        end
      RUBY
      expect(offenses.first[:message]).to include('before_validation')
    end

    it 'registers an offense in after_save block' do
      offenses = expect_offense(<<~RUBY)
        class User < ApplicationRecord
          after_save do
            UserMailer.deliver_later
          end
        end
      RUBY
      expect(offenses.first[:message]).to include('after_save')
    end

    it 'registers an offense in before_create block' do
      offenses = expect_offense(<<~RUBY)
        class User < ApplicationRecord
          before_create do
            UserMailer.deliver_later
          end
        end
      RUBY
      expect(offenses.first[:message]).to include('before_create')
    end

    it 'registers an offense in before_update block' do
      offenses = expect_offense(<<~RUBY)
        class User < ApplicationRecord
          before_update do
            UserMailer.deliver_later
          end
        end
      RUBY
      expect(offenses.first[:message]).to include('before_update')
    end

    it 'registers an offense in before_destroy block' do
      offenses = expect_offense(<<~RUBY)
        class User < ApplicationRecord
          before_destroy do
            UserMailer.deliver_later
          end
        end
      RUBY
      expect(offenses.first[:message]).to include('before_destroy')
    end
  end

  describe 'symbol argument form callbacks' do
    it 'registers an offense when calling a background job in before_save' do
      offenses = expect_offense(<<~RUBY)
        class User < ApplicationRecord
          before_save :send_notification

          def send_notification
            UserMailer.deliver_later
          end
        end
      RUBY
      expect(offenses.first[:message]).to include('before_save')
    end

    it 'registers an offense for symbol callback in before_create' do
      offenses = expect_offense(<<~RUBY)
        class User < ApplicationRecord
          before_create :do_stuff

          def do_stuff
            UserMailer.deliver_later
          end
        end
      RUBY
      expect(offenses.first[:message]).to include('before_create')
    end
  end

  describe 'external library calls' do
    it 'registers an offense for RestClient calls' do
      offenses = expect_offense(<<~RUBY)
        class User < ApplicationRecord
          before_save do
            RestClient.get('http://example.com')
          end
        end
      RUBY
      expect(offenses.first[:message]).to include('before_save')
    end

    it 'registers an offense for Faraday calls' do
      offenses = expect_offense(<<~RUBY)
        class User < ApplicationRecord
          before_save do
            Faraday.get('http://example.com')
          end
        end
      RUBY
      expect(offenses.first[:message]).to include('before_save')
    end

    it 'registers an offense for HTTParty calls' do
      offenses = expect_offense(<<~RUBY)
        class User < ApplicationRecord
          before_save do
            HTTParty.get('http://example.com')
          end
        end
      RUBY
      expect(offenses.first[:message]).to include('before_save')
    end

    it 'registers an offense for Net calls' do
      offenses = expect_offense(<<~RUBY)
        class User < ApplicationRecord
          before_save do
            Net.start('example.com')
          end
        end
      RUBY
      expect(offenses.first[:message]).to include('before_save')
    end

    it 'registers an offense for Sidekiq calls' do
      offenses = expect_offense(<<~RUBY)
        class User < ApplicationRecord
          before_save do
            Sidekiq.enqueue(SomeWorker)
          end
        end
      RUBY
      expect(offenses.first[:message]).to include('before_save')
    end

    it 'registers an offense for ActionCable calls' do
      offenses = expect_offense(<<~RUBY)
        class User < ApplicationRecord
          before_save do
            ActionCable.broadcast('channel', data)
          end
        end
      RUBY
      expect(offenses.first[:message]).to include('before_save')
    end
  end

  describe 'async delivery methods' do
    it 'registers an offense for deliver_later' do
      offenses = expect_offense(<<~RUBY)
        class User < ApplicationRecord
          before_save do
            UserMailer.deliver_later
          end
        end
      RUBY
      expect(offenses.first[:message]).to include('before_save')
    end

    it 'registers an offense for perform_later' do
      offenses = expect_offense(<<~RUBY)
        class User < ApplicationRecord
          before_save do
            SomeJob.perform_later
          end
        end
      RUBY
      expect(offenses.first[:message]).to include('before_save')
    end

    it 'registers an offense for broadcast_later' do
      offenses = expect_offense(<<~RUBY)
        class User < ApplicationRecord
          before_save do
            SomeChannel.broadcast_later
          end
        end
      RUBY
      expect(offenses.first[:message]).to include('before_save')
    end
  end

  describe 'side effect persistence on other objects' do
    it 'registers an offense for save on a constant' do
      offenses = expect_offense(<<~RUBY)
        class User < ApplicationRecord
          before_save do
            OtherRecord.save
          end
        end
      RUBY
      expect(offenses.first[:message]).to include('before_save')
    end

    it 'registers an offense for save! on a local variable' do
      offenses = expect_offense(<<~RUBY)
        class User < ApplicationRecord
          before_save do
            record = OtherRecord.new
            record.save!
          end
        end
      RUBY
      expect(offenses.size).to be >= 1
      expect(offenses.any? { |o| o[:code].include?('save!') }).to be true
    end

    it 'registers an offense for update on an association' do
      offenses = expect_offense(<<~RUBY)
        class User < ApplicationRecord
          before_save do
            profile.update(name: 'test')
          end
        end
      RUBY
      expect(offenses.first[:message]).to include('before_save')
    end

    it 'registers an offense for update! on an association' do
      offenses = expect_offense(<<~RUBY)
        class User < ApplicationRecord
          before_save do
            profile.update!(name: 'test')
          end
        end
      RUBY
      expect(offenses.first[:message]).to include('before_save')
    end

    it 'registers an offense for destroy on an association' do
      offenses = expect_offense(<<~RUBY)
        class User < ApplicationRecord
          before_save do
            profile.destroy
          end
        end
      RUBY
      expect(offenses.first[:message]).to include('before_save')
    end

    it 'registers an offense for destroy! on an association' do
      offenses = expect_offense(<<~RUBY)
        class User < ApplicationRecord
          before_save do
            profile.destroy!
          end
        end
      RUBY
      expect(offenses.first[:message]).to include('before_save')
    end

    it 'registers an offense for create on a constant' do
      offenses = expect_offense(<<~RUBY)
        class User < ApplicationRecord
          before_save do
            AuditLog.create(message: 'changed')
          end
        end
      RUBY
      expect(offenses.first[:message]).to include('before_save')
    end

    it 'registers an offense for create! on a constant' do
      offenses = expect_offense(<<~RUBY)
        class User < ApplicationRecord
          before_save do
            AuditLog.create!(message: 'changed')
          end
        end
      RUBY
      expect(offenses.first[:message]).to include('before_save')
    end
  end

  describe 'multiple offenses' do
    it 'registers multiple offenses in the same callback' do
      offenses = expect_offense(<<~RUBY)
        class User < ApplicationRecord
          before_save do
            UserMailer.deliver_later
            SomeJob.perform_later
          end
        end
      RUBY
      expect(offenses.size).to eq(2)
    end

    it 'registers offenses across multiple callbacks' do
      offenses = expect_offense(<<~RUBY)
        class User < ApplicationRecord
          before_create :do_stuff

          before_save do
            UserMailer.deliver_later
          end

          after_save do
            pp "butts"
          end

          def do_stuff
            UserMailer.deliver_later
          end
        end
      RUBY
      expect(offenses.size).to eq(2)
    end
  end

  it 'registers an offense for synchronous mailer delivery' do
    offenses = expect_offense(<<~RUBY)
      class User < ApplicationRecord
        after_save { UserMailer.welcome(self).deliver_now }
      end
    RUBY
    expect(offenses.first[:message]).to include('after_save')
  end

  it 'registers an offense when calling save on self' do
    offenses = expect_offense(<<~RUBY)
      class User < ApplicationRecord
        before_save :trigger_recursion

        def trigger_recursion
          save
        end
      end
    RUBY
    expect(offenses.first[:message]).to include('before_save')
  end

  it 'registers an offense when the side effect is inside a conditional' do
    offenses = expect_offense(<<~RUBY)
      class User < ApplicationRecord
        before_create do
          if email_changed?
            NewsletterSDK.subscribe(email)
          end
        end
      end
    RUBY
    expect(offenses.first[:message]).to include('before_create')
  end

  it 'registers an offense for touch and update_columns' do
    offenses = expect_offense(<<~RUBY)
      class User < ApplicationRecord
        after_create do
          profile.touch
          other_record.update_columns(status: 'ready')
        end
      end
    RUBY
    expect(offenses.size).to eq(2)
  end
end
