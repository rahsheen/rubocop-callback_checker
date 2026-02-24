# frozen_string_literal: true

module RuboCop
  module Cop
    module CallbackChecker
      class NoSideEffectsInCallbacks < Base
        MSG = "Avoid side effects (API calls, mailers, background jobs, or modifying other records) " \
              "in %<callback>s. Use `after_commit` instead."

        SIDE_EFFECT_SENSITIVE_CALLBACKS = %i[
          before_validation before_save after_save
          before_create before_update before_destroy
        ].freeze

        def_node_matcher :external_library_call?, <<~PATTERN
          (send (const {nil? cbase} {:RestClient :Faraday :HTTParty :Net :Sidekiq :ActionCable}) ...)
        PATTERN

        def_node_matcher :async_delivery?, <<~PATTERN
          (send (const ...) {:deliver_later :perform_later :broadcast_later})
        PATTERN

        # Targets persistence on Constants, local vars, or association calls
        def_node_matcher :side_effect_persistence?, <<~PATTERN
          (send {const (lvar _) (send _ _)} {:save :save! :update :update! :destroy :destroy! :create :create! :create_or_find!})
        PATTERN

        def on_send(node)
          return unless SIDE_EFFECT_SENSITIVE_CALLBACKS.include?(node.method_name)

          # 1. Block form: before_save { ... }
          check_method_contents(node.block_node.body, node.method_name) if node.block_literal?

          # 2. Argument form
          node.arguments.each do |arg|
            if arg.sym_type?
              check_symbol_callback(node, arg.value)
            elsif arg.block_type? || arg.lambda? || arg.proc? || arg.send_type?
              # arg.body works for blocks/lambdas to get the executable logic
              check_method_contents(arg.body, node.method_name)
            end
          end
        end

        private

        def check_symbol_callback(node, method_name)
          # Find the class/module containing the callback
          scope = node.each_ancestor(:class, :module).first
          return unless scope

          # Search for the method definition anywhere in the class
          method_def = scope.each_descendant(:def).find { |d| d.method_name == method_name }
          return unless method_def

          check_method_contents(method_def.body, node.method_name)
        end

        def check_method_contents(node, callback_name)
          return unless node

          # Use each_node to include the root node if it's a 'send'
          node.each_node(:send) do |send_node|
            next unless external_library_call?(send_node) ||
                        async_delivery?(send_node) ||
                        side_effect_persistence?(send_node)

            add_offense(send_node, message: format(MSG, callback: callback_name))
          end
        end
      end
    end
  end
end
