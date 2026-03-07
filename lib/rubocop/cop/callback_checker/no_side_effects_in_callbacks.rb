# frozen_string_literal: true

module RuboCop
  module Cop
    module CallbackChecker
      # This cop checks for side effects (API calls, mailers, background jobs, or modifying other records)
      # in Active Record callbacks that execute within a database transaction.
      #
      # @example
      #   # bad
      #   after_create { UserMailer.welcome(self).deliver_now }
      #   after_save :notify_external_api
      #
      #   # good
      #   after_commit :notify_external_api, on: :create
      class NoSideEffectsInCallbacks < Base
        MSG = "Avoid side effects (API calls, mailers, background jobs, or modifying other records) " \
              "in %<callback>s. Use `after_commit` instead."

        SIDE_EFFECT_SENSITIVE_CALLBACKS = %i[
          before_validation before_save after_save
          before_create after_create
          before_update after_update
          before_destroy after_destroy
          around_save around_create around_update around_destroy
          after_touch
        ].freeze

        # Added common HTTP clients and SDKs
        def_node_matcher :external_library_call?, <<~PATTERN
          (send (const {nil? cbase} {:RestClient :Faraday :HTTParty :Net :HTTP :Excon :Typhoeus :Stripe :Aws :Intercom :Sidekiq :ActionCable}) ...)
        PATTERN

        # Match calls to any constant (e.g., NewsletterSDK, CustomSDK, etc.)
        def_node_matcher :constant_method_call?, <<~PATTERN
          (send (const {nil? cbase} _) ...)
        PATTERN

        # Added synchronous delivery and ActiveJob/Sidekiq variants
        def_node_matcher :async_delivery?, <<~PATTERN
          (send ... {:deliver_now :deliver_now! :deliver_later :deliver_later! :perform_later :perform_async :perform_at :perform_in :broadcast_later})
        PATTERN

        # Catches persistence on other objects or explicit self-saves (which trigger recursion/extra DB hits)
        def_node_matcher :side_effect_persistence?, <<~PATTERN
          (send {const (lvar _) (send _ _)} {:save :save! :update :update! :update_columns :destroy :destroy! :create :create! :toggle! :touch})
        PATTERN

        # Catches bare method calls like save, update, etc. (implicitly on self)
        def_node_matcher :bare_persistence_call?, <<~PATTERN
          (send nil? {:save :save! :update :update! :update_columns :destroy :destroy! :create :create! :toggle! :touch})
        PATTERN

        def on_send(node)
          return unless side_effect_sensitive_callback?(node)

          check_callback_block(node) if node.block_literal?
          check_callback_arguments(node)
        end

        private

        def side_effect_sensitive_callback?(node)
          SIDE_EFFECT_SENSITIVE_CALLBACKS.include?(node.method_name)
        end

        def check_callback_block(node)
          check_method_contents(node.block_node.body, node.method_name)
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
            check_method_contents(arg.body, node.method_name)
          end
        end

        def callback_proc?(arg)
          arg.block_type? || arg.lambda? || arg.proc?
        end

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
            next unless side_effect_call?(send_node)

            add_offense(send_node, message: format(MSG, callback: callback_name))
          end
        end

        def side_effect_call?(send_node)
          external_library_call?(send_node) ||
            async_delivery?(send_node) ||
            side_effect_persistence?(send_node) ||
            bare_persistence_call?(send_node) ||
            suspicious_constant_call?(send_node)
        end

        def suspicious_constant_call?(send_node)
          return false unless constant_method_call?(send_node)

          # Exclude known safe Rails constants and common utilities
          receiver = send_node.receiver
          return false unless receiver&.const_type?

          const_name = receiver.const_name
          safe_constants = %w[
            Rails ActiveRecord ActiveSupport ActiveModel ActionController
            ActionView ActionMailer ApplicationRecord
            File Dir Pathname URI JSON YAML CSV
            Time Date DateTime
            Math Random SecureRandom
            Logger
          ]

          # If it's a known safe constant, it's not suspicious
          return false if safe_constants.any? { |safe| const_name.start_with?(safe) }

          # If it's calling a method that looks like a side effect, flag it
          # This will catch things like NewsletterSDK.subscribe, CustomAPI.call, etc.
          true
        end
      end
    end
  end
end
