# frozen_string_literal: true

module RuboCop
  module Cop
    module CallbackChecker
      # This cop enforces using named methods instead of procs or strings
      # for callback conditionals (if: and unless:).
      #
      # Procs and strings are harder to debug, test, and override in subclasses.
      # Named methods provide better readability and maintainability.
      #
      # @example
      #   # bad
      #   before_save :do_thing, if: -> { status == 'active' && !deleted? }
      #   after_create :notify, unless: proc { Rails.env.test? }
      #   before_validation :check, if: "status == 'active'"
      #
      #   # good
      #   before_save :do_thing, if: :active_and_present?
      #   after_create :notify, unless: :test_environment?
      #   before_validation :check, if: :active?
      #
      #   private
      #
      #   def active_and_present?
      #     status == 'active' && !deleted?
      #   end
      class ConditionalStyle < Base
        MSG = "Use a named method instead of a %<type>s for callback conditionals. " \
              "Extract the logic to a private method with a descriptive name."

        CALLBACK_METHODS = %i[
          before_validation after_validation
          before_save after_save around_save
          before_create after_create around_create
          before_update after_update around_update
          before_destroy after_destroy around_destroy
          after_commit after_rollback
          after_touch
          after_create_commit after_update_commit after_destroy_commit after_save_commit
        ].freeze

        CONDITIONAL_KEYS = %i[if unless].freeze

        def on_send(node)
          return unless callback_method?(node)
          
          check_callback_conditionals(node)
        end

        private

        def callback_method?(node)
          CALLBACK_METHODS.include?(node.method_name)
        end

        def check_callback_conditionals(node)
          # Look for hash arguments that contain if: or unless: keys
          node.arguments.each do |arg|
            next unless arg.hash_type?

            arg.pairs.each do |pair|
              check_conditional_pair(pair)
            end
          end
        end

        def check_conditional_pair(pair)
          return unless conditional_key?(pair.key)

          value = pair.value

          if value.lambda? || value.block_type?
            add_offense(value, message: format(MSG, type: 'proc/lambda'))
          elsif value.str_type?
            add_offense(value, message: format(MSG, type: 'string'))
          end
        end

        def conditional_key?(key)
          return false unless key.sym_type?
          
          CONDITIONAL_KEYS.include?(key.value)
        end
      end
    end
  end
end
