# frozen_string_literal: true

module RuboCop
  module Cop
    module CallbackChecker
      # This cop enforces that callback methods should be short and simple.
      # Long callback methods indicate that business logic is leaking into the model
      # and should be extracted to a service object.
      #
      # @example Max: 5 (default)
      #   # bad
      #   class User < ApplicationRecord
      #     before_save :complex_setup
      #
      #     def complex_setup
      #       self.name = name.strip
      #       self.email = email.downcase
      #       self.token = generate_secure_token
      #       self.status = calculate_status
      #       self.score = compute_score
      #       self.metadata = build_metadata
      #       self.tags = process_tags
      #     end
      #   end
      #
      #   # good
      #   class User < ApplicationRecord
      #     before_save :normalize_fields
      #
      #     def normalize_fields
      #       self.name = name.strip
      #       self.email = email.downcase
      #     end
      #   end
      #
      #   # better - extract to service
      #   class User < ApplicationRecord
      #     # No callback, call UserRegistrationService.new(user).call from controller
      #   end
      class CallbackMethodLength < Base
        MSG = "Callback method `%<method>s` is too long (%<length>d lines). " \
              "Max allowed: %<max>d lines. Extract complex logic to a service object."

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

        def on_send(node)
          return unless callback_method?(node)
          
          # Only check symbol arguments (method name references)
          node.arguments.each do |arg|
            check_callback_argument(node, arg) if arg.sym_type?
          end
        end

        private

        def callback_method?(node)
          CALLBACK_METHODS.include?(node.method_name)
        end

        def check_callback_argument(callback_node, arg)
          method_name = arg.value
          scope = callback_node.each_ancestor(:class, :module).first
          return unless scope

          method_def = find_method_definition(scope, method_name)
          return unless method_def

          check_method_length(method_def, method_name)
        end

        def find_method_definition(scope, method_name)
          scope.each_descendant(:def).find { |def_node| def_node.method_name == method_name }
        end

        def check_method_length(method_node, method_name)
          return unless method_node.body

          length = method_body_length(method_node)
          max_length = cop_config['Max'] || 5

          return if length <= max_length

          add_offense(
            method_node,
            message: format(MSG, method: method_name, length: length, max: max_length)
          )
        end

        def method_body_length(method_node)
          return 0 unless method_node.body

          body = method_node.body
          
          # Calculate line count
          first_line = body.first_line
          last_line = body.last_line
          
          # Count non-empty lines
          (first_line..last_line).count do |line_number|
            line = processed_source.lines[line_number - 1]
            line && !line.strip.empty?
          end
        end
      end
    end
  end
end
