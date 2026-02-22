# frozen_string_literal: true

module RuboCop
  module Cop
    module CallbackChecker
      # This cop prevents side effects (API calls, mailers, background jobs,
      # or updates to other records) in ActiveRecord callbacks that run
      # before the database transaction is committed.
      class NoSideEffectsInCallbacks < Base
        # The recommended alternative is to use after_commit for side effects.
        MSG = "Avoid side effects (API calls, mailers, background jobs, or modifying other records) " \
              "in %<callback>s. Use `after_commit` instead."

        # Callbacks that run *before* commit (before_* and after_save)
        SIDE_EFFECT_SENSITIVE_CALLBACKS = %i[before_validation before_save after_save before_create before_update
                                             before_destroy].freeze

        # 1. Methods that typically indicate a side effect (Expanded List)
        SIDE_EFFECT_INDICATORS = %i[
          deliver_later perform_later
          post get put delete request call
          save! update! destroy! save update destroy
          broadcast_to broadcast_later puts print write
        ].freeze

        # 2. Receivers that indicate a side effect (e.g., Faraday.get, ActionCable.server.broadcast)
        EXTERNAL_CONSTANT_INDICATORS = %i[
          RestClient Faraday HTTParty
          Net::HTTP Sidekiq::Client Resque
          ActionCable
        ].freeze

        # def on_class(class_node)
        #   defined_callbacks(class_node).each do |callback_call_node|
        #     pp "got callback node #{callback_call_node}"
        #     # Get the arguments array from the :send node (children after index 1)
        #     arguments = callback_call_node.arguments
        #     callback_method = callback_call_node.method_name
        #     pp callback_call_node
        #
        #     # Check if there is a first argument and if it's a Symbol Literal (:sym)
        #     first_arg_node = arguments.first
        #
        #     if first_arg_node.sym_type?
        #       pp "Got sym"
        #       # For a :sym node, the actual value (the symbol) is its value
        #       callback_method_name = first_arg_node.value
        #
        #       pp "on_class callback: #{callback_method_name}"
        #
        #       # Now you can use the corrected name to find the definition
        #       method_def_node = method_definition_for(class_node, callback_method_name)
        #       if method_def_node
        #         # 3. Get the method body from the definition node
        #         # A :def node typically has children: [method_name, arguments_node, body_node]
        #         method_body_node = method_def_node.children[2]
        #
        #         # Now you can check the contents of method_body_node
        #         # check_method_body(method_body_node)
        #         check_method_contents(method_body_node, callback_method)
        #       else
        #         # Handle cases where the callback might be defined in a module,
        #         # a parent class, or is a lambda/proc, etc.
        #         pp "Could not find definition for: #{callback_method_name}"
        #       end
        #     else
        #       pp "Node was not sym type"
        #     end
        #   end
        # end

        def on_send(node)
          # 1. Check if the called method is one of our sensitive callbacks
          return unless SIDE_EFFECT_SENSITIVE_CALLBACKS.include?(node.method_name)

          # 2. If it's a block-less call, the callback logic must be in the arguments.

          # Check for Symbol argument (:method_name) or Lambda argument (-> { ... })
          first_arg_node = node.arguments.first

          if first_arg_node&.sym_type?
            # Handle Case: before_save :method_name
            callback_method_name = first_arg_node.value
            check_symbol_callback(node, callback_method_name)

          elsif first_arg_node&.block_type?
            # Handle Case: before_save -> { ... }
            # Body is the third child of the block node
            method_body_node = first_arg_node.children[2]
            check_method_contents(method_body_node)
          end
        end

        def on_block(node)
          # The method being called is the first child of the :block node
          send_node = node.children.first
          callback_method_name = send_node.method_name

          # 1. Check if the method inside the block is one of our sensitive callbacks
          return unless send_node.send_type? && SIDE_EFFECT_SENSITIVE_CALLBACKS.include?(callback_method_name)

          # 2. The block body is the third child of the :block node
          method_body_node = node.children[2]
          check_method_contents(method_body_node, callback_method_name)
        end

        private

        # Helper for Symbol callbacks
        def check_symbol_callback(node, callback_method_name)
          parent = node.ancestors.find do |ancestor|
            ancestor.class_type? || ancestor.module_type?
          end

          method_def_node = method_definition_for(parent, callback_method_name)

          if method_def_node
            # Children of :def node: [method_name, arguments_node, body_node]
            method_body_node = method_def_node.children[2]
            pp "got method #{method_body_node} #{node.method_name}"
            check_method_contents(method_body_node, node.method_name)
          end
        end

        def method_definition_for(class_node, method_name)
          class_body = class_node.children[2]
          return nil unless class_body

          pp "Finding #{method_name}"
          # Check the body itself first
          if class_body.def_type? && class_body.method_name == method_name
            pp "Found in body"
            return class_body
          end

          # Iterate descendants and return the node immediately when found
          class_body.each_descendant do |node|
            if node.def_type? && node.method_name == method_name
              pp "Found in descendants"
              return node
            end
          end

          nil
        end

        # Traverses the AST of the callback body to look for side effects
        def check_method_contents(node, callback_method)
          # Recursively search the AST below the callback definition for method calls (:send nodes)
          node.each_node(:send) do |send_node|
            # --- Check 1: Explicit Method Name ---
            pp "checking #{send_node}"
            if SIDE_EFFECT_INDICATORS.include?(send_node.method_name)
              # Check for methods like `deliver_later` or generic side effect methods.
              add_offense_for_side_effect(send_node, callback_method)
              next
            end

            # --- Check 2: External Library Constant Receiver ---
            if check_for_external_constants(send_node)
              # Check for patterns like `Faraday.get` or `Sidekiq::Client.push`.
              add_offense_for_side_effect(send_node, callback_method)
              next
            end

            # --- Check 3: Any method call in the callback ---
            # Exclude internal method calls (e.g., self.method_name or method_name)
            unless internal_method_call?(send_node) || send_node.assignment?
              add_offense_for_side_effect(send_node, callback_method)
            end
          end
        end

        # Helper to detect if the receiver of the method call is an external constant
        def check_for_external_constants(send_node)
          receiver = send_node.receiver

          # We are looking for a method call like `CONSTANT.method`
          return unless receiver&.const_type?

          # For nested constants (e.g., Sidekiq::Client), we only check the top level
          # which is the first child of the constant node
          constant_name = receiver.children.first&.children&.last || receiver.children.last

          EXTERNAL_CONSTANT_INDICATORS.include?(constant_name)
        end

        # Helper to determine if a method call is internal (e.g., self.method_name or method_name)
        def internal_method_call?(send_node)
          receiver = send_node.receiver

          # If the receiver is `self`, nil (implicit self), or the method is an assignment (e.g., `self.name =`), it's an internal method call
          receiver.nil? || receiver.self_type? || send_node.assignment? || internal_method_call?(send_node)
        end

        # Helper to report the offense
        def add_offense_for_side_effect(node, callback_method)
          add_offense(
            node,
            message: format(MSG, callback: callback_method)
          )
        end
      end
    end
  end
end
