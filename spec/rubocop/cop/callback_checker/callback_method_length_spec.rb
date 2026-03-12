# frozen_string_literal: true

RSpec.describe RuboCop::Cop::CallbackChecker::CallbackMethodLength, :config do
  let(:config) do
    RuboCop::Config.new(
      'CallbackChecker/CallbackMethodLength' => {
        'Enabled' => true,
        'Max' => 5
      },
      'CallbackChecker/AvoidSelfPersistence' => { 'Enabled' => false },
      'CallbackChecker/NoSideEffectsInCallbacks' => { 'Enabled' => false },
      'CallbackChecker/AttributeAssignmentOnly' => { 'Enabled' => false }
    )
  end

  context 'when callback method is within the limit' do
    it 'does not register an offense' do
      expect_no_offenses(<<~RUBY)
        class User < ApplicationRecord
          before_save :normalize_fields

          def normalize_fields
            self.name = name.strip
            self.email = email.downcase
          end
        end
      RUBY
    end
  end

  context 'when callback method is at the limit' do
    it 'does not register an offense' do
      expect_no_offenses(<<~RUBY)
        class User < ApplicationRecord
          before_save :setup

          def setup
            self.name = name.strip
            self.email = email.downcase
            self.status = 'active'
            self.token = generate_token
            self.score = 0
          end
        end
      RUBY
    end
  end

  context 'when callback method exceeds the limit' do
    it 'registers an offense' do
      expect_offense(<<~RUBY)
        class User < ApplicationRecord
          before_save :complex_setup

          def complex_setup
          ^^^^^^^^^^^^^^^^^ Callback method `complex_setup` is too long (6 lines). Max allowed: 5 lines. Extract complex logic to a service object.
            self.name = name.strip
            self.email = email.downcase
            self.token = generate_secure_token
            self.status = calculate_status
            self.score = compute_score
            self.metadata = build_metadata
          end
        end
      RUBY
    end
  end

  context 'when callback method is significantly too long' do
    it 'registers an offense' do
      expect_offense(<<~RUBY)
        class User < ApplicationRecord
          after_create :send_notifications

          def send_notifications
          ^^^^^^^^^^^^^^^^^^^^^^ Callback method `send_notifications` is too long (10 lines). Max allowed: 5 lines. Extract complex logic to a service object.
            self.name = name.strip
            self.email = email.downcase
            self.status = 'active'
            self.token = generate_token
            self.score = 0
            self.metadata = {}
            self.tags = []
            self.preferences = default_preferences
            self.settings = default_settings
            self.flags = []
          end
        end
      RUBY
    end
  end

  context 'when using before_validation callback' do
    it 'registers an offense for long method' do
      expect_offense(<<~RUBY)
        class User < ApplicationRecord
          before_validation :validate_data

          def validate_data
          ^^^^^^^^^^^^^^^^^ Callback method `validate_data` is too long (6 lines). Max allowed: 5 lines. Extract complex logic to a service object.
            self.name = name.strip if name
            self.email = email.downcase if email
            self.phone = normalize_phone(phone)
            self.address = normalize_address(address)
            self.city = city.titleize if city
            self.country = country.upcase if country
          end
        end
      RUBY
    end
  end

  context 'when using after_commit callback' do
    it 'registers an offense for long method' do
      expect_offense(<<~RUBY)
        class User < ApplicationRecord
          after_commit :notify_services

          def notify_services
          ^^^^^^^^^^^^^^^^^^^ Callback method `notify_services` is too long (7 lines). Max allowed: 5 lines. Extract complex logic to a service object.
            NotificationService.notify(self)
            AnalyticsService.track(self)
            EmailService.send_welcome(self)
            SlackService.notify_team(self)
            WebhookService.trigger(self)
            LogService.log_creation(self)
            CacheService.invalidate(self)
          end
        end
      RUBY
    end
  end

  context 'when using around_save callback' do
    it 'registers an offense for long method' do
      expect_offense(<<~RUBY)
        class User < ApplicationRecord
          around_save :wrap_save

          def wrap_save
          ^^^^^^^^^^^^^ Callback method `wrap_save` is too long (8 lines). Max allowed: 5 lines. Extract complex logic to a service object.
            start_time = Time.current
            self.processing = true
            result = yield
            self.processing = false
            self.last_processed = Time.current
            self.processing_time = Time.current - start_time
            log_processing_time
            result
          end
        end
      RUBY
    end
  end

  context 'when non-callback method is long' do
    it 'does not register an offense' do
      expect_no_offenses(<<~RUBY)
        class User < ApplicationRecord
          def some_long_method
            line_1
            line_2
            line_3
            line_4
            line_5
            line_6
            line_7
            line_8
            line_9
            line_10
          end
        end
      RUBY
    end
  end

  context 'when callback uses block syntax' do
    it 'does not register an offense' do
      expect_no_offenses(<<~RUBY)
        class User < ApplicationRecord
          before_save do
            self.name = name.strip
            self.email = email.downcase
            self.token = generate_secure_token
            self.status = calculate_status
            self.score = compute_score
            self.metadata = build_metadata
          end
        end
      RUBY
    end
  end

  context 'when multiple callbacks reference same method' do
    it 'registers offense only once per method definition' do
      expect_offense(<<~RUBY)
        class User < ApplicationRecord
          before_save :setup
          before_create :setup

          def setup
          ^^^^^^^^^ Callback method `setup` is too long (6 lines). Max allowed: 5 lines. Extract complex logic to a service object.
            self.name = name.strip
            self.email = email.downcase
            self.status = 'active'
            self.token = generate_token
            self.score = 0
            self.metadata = {}
          end
        end
      RUBY
    end
  end

  context 'when callback method has empty lines' do
    it 'does not count empty lines' do
      expect_no_offenses(<<~RUBY)
        class User < ApplicationRecord
          before_save :setup

          def setup
            self.name = name.strip

            self.email = email.downcase

            self.status = 'active'
          end
        end
      RUBY
    end
  end

  context 'when callback method has comments' do
    it 'counts comment lines' do
      expect_no_offenses(<<~RUBY)
        class User < ApplicationRecord
          before_save :setup

          def setup
            # Normalize name
            self.name = name.strip
            # Normalize email
            self.email = email.downcase
          end
        end
      RUBY
    end
  end

  context 'when method is not found in class' do
    it 'does not register an offense' do
      expect_no_offenses(<<~RUBY)
        class User < ApplicationRecord
          before_save :nonexistent_method
        end
      RUBY
    end
  end

  context 'when using multiple callbacks with different lengths' do
    it 'registers offenses for long methods only' do
      expect_offense(<<~RUBY)
        class User < ApplicationRecord
          before_save :short_method
          after_save :long_method

          def short_method
            self.name = name.strip
          end

          def long_method
          ^^^^^^^^^^^^^^^ Callback method `long_method` is too long (6 lines). Max allowed: 5 lines. Extract complex logic to a service object.
            step_1
            step_2
            step_3
            step_4
            step_5
            step_6
          end
        end
      RUBY
    end
  end

  context 'when callback method is a one-liner' do
    it 'does not register an offense' do
      expect_no_offenses(<<~RUBY)
        class User < ApplicationRecord
          before_save :normalize

          def normalize
            self.name = name.strip
          end
        end
      RUBY
    end
  end

  context 'when callback method has only whitespace' do
    it 'does not count whitespace' do
      expect_no_offenses(<<~RUBY)
        class User < ApplicationRecord
          before_save :setup

          def setup
            
            self.name = name.strip
            
            self.email = email.downcase
            
          end
        end
      RUBY
    end
  end
end
