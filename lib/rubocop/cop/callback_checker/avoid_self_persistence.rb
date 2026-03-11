# frozen_string_literal: true

module RuboCop
  module Cop
    module CallbackChecker
      # This cop checks for persistence method calls on self within Active Record callbacks.
      # Calling .save, .update, .toggle!, etc. on self inside a callback can trigger
      # infinite loops or run the entire callback chain multiple times.
      #
      # @example
      #   # bad
      #   after_save :activate_user
      #   def activate_user
      #     self.save
      #   end
      #
      #   # bad
      #   before_validation { update(status: 'active') }
      #
      #   # good
      #   after_save :activate_user
      #   def activate_user
      #     self.status = 'active'
      #   end
      class AvoidSelfPersistence < Base
        MSG = "Avoid calling `%<method>s` on self within `%<callback>s`. " \
              "This can trigger infinite loops or run callbacks multiple times. " \
              "Assign attributes directly instead: `self.attribute = value`."

        CALLBACK_METHODS = %i[
          before_validation after_validation
          before_save after_save around_save
          before_create after_create around_create
          before_update after_update around_update
          before_destroy after_destroy around_destroy
          after_touch
        ].freeze

        PERSISTENCE_METHODS = %i[
          save save! update update! update_attribute update_attributes
          update_attributes! update_column update_columns
          toggle! increment! decrement! touch
        ].freeze

        def on_send(node)
          return unless callback_method?(node)

          check_callback_block(node) if node.block_node
          check_callback_arguments(node)
        end

        private

        def callback_method?(node)
          CALLBACK_METHODS.include?(node.method_name)
        end

        def check_callback_block(node)
          check_block_for_persistence(node.block_node.body, node.method_name) if node.block_node.body
        end

        def check_callback_arguments(node)
          node.arguments.each do |arg|
            process_callback_argument(node, arg)
          end
        end

        def process_callback_argument(node, arg)
          if arg.sym_type?
            check_symbol_callback(node, arg.value)
          elsif callback_proc?(arg)
            check_block_for_persistence(arg.body, node.method_name)
          end
        end

        def callback_proc?(arg)
          arg.block_type? || arg.lambda? || arg.proc?
        end

        def check_symbol_callback(node, method_name)
          scope = node.each_ancestor(:class, :module).first
          return unless scope

          method_def = scope.each_descendant(:def).find { |d| d.method_name == method_name }
          return unless method_def

          check_block_for_persistence(method_def.body, node.method_name)
        end

        def check_block_for_persistence(node, callback_name)
          return unless node

          node.each_descendant(:send) do |send_node|
            check_for_self_persistence(send_node, callback_name)
          end
        end

        def check_for_self_persistence(send_node, callback_name)
          return unless PERSISTENCE_METHODS.include?(send_node.method_name)
          return unless called_on_self?(send_node)

          add_offense(
            send_node,
            message: format(MSG, method: send_node.method_name, callback: callback_name)
          )
        end

        def called_on_self?(send_node)
          # No receiver means implicit self
          return true if send_node.receiver.nil?

          # Explicit self reference
          send_node.receiver.self_type?
        end
      end
    end
  end
end
