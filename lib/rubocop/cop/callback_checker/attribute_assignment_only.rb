# frozen_string_literal: true

module RuboCop
  module Cop
    module CallbackChecker
      # This cop checks for persistence method calls on self within before_* callbacks
      # (before_save, before_validation, before_create, before_update).
      # It suggests using attribute assignment instead, since the object will be
      # automatically persisted after the callback completes.
      #
      # @example
      #   # bad
      #   class User < ApplicationRecord
      #     before_save :normalize_data
      #
      #     def normalize_data
      #       update(name: name.strip)
      #     end
      #   end
      #
      #   # good
      #   class User < ApplicationRecord
      #     before_save :normalize_data
      #
      #     def normalize_data
      #       self.name = name.strip
      #     end
      #   end
      class AttributeAssignmentOnly < Base
        MSG = 'Use attribute assignment (`self.%<attribute>s = value`) instead of `%<method>s` in `%<callback>s`. ' \
              'The object will be persisted automatically after the callback completes.'

        PERSISTENCE_METHODS = %i[
          update
          update!
          update_columns
          update_column
          update_attribute
          update_attributes
          update_attributes!
        ].freeze

        BEFORE_CALLBACKS = %i[
          before_save
          before_validation
          before_create
          before_update
        ].freeze

        def_node_matcher :callback_method?, <<~PATTERN
          (send nil? {#{BEFORE_CALLBACKS.map(&:inspect).join(' ')}} ...)
        PATTERN

        def_node_matcher :persistence_call?, <<~PATTERN
          (send {nil? (self)} {#{PERSISTENCE_METHODS.map(&:inspect).join(' ')}} ...)
        PATTERN

        def_node_matcher :hash_argument?, <<~PATTERN
          (send {nil? (self)} _ (hash ...))
        PATTERN

        def_node_matcher :first_hash_key, <<~PATTERN
          (send {nil? (self)} _ (hash (pair (sym $_) _) ...))
        PATTERN

        def_node_matcher :first_symbol_arg, <<~PATTERN
          (send {nil? (self)} _ (sym $_) ...)
        PATTERN

        def on_class(node)
          @current_callbacks = {}

          node.each_descendant(:send) do |send_node|
            next unless callback_method?(send_node)

            callback_name = send_node.method_name
            callback_args = send_node.arguments

            callback_args.each do |arg|
              if arg.sym_type?
                method_name = arg.value
                @current_callbacks[method_name] = callback_name
              elsif arg.block_type? || arg.numblock_type?
                check_block_for_persistence(arg, callback_name)
              end
            end

            check_block_for_persistence(send_node.block_node, callback_name) if send_node.block_node
          end

          node.each_descendant(:def) do |def_node|
            method_name = def_node.method_name
            callback_name = @current_callbacks[method_name]

            next unless callback_name

            check_method_for_persistence(def_node, callback_name)
          end
        end

        private

        def check_block_for_persistence(block_node, callback_name)
          block_node.each_descendant(:send) do |send_node|
            next unless persistence_call?(send_node)

            add_offense_for_node(send_node, callback_name)
          end
        end

        def check_method_for_persistence(method_node, callback_name)
          method_node.each_descendant(:send) do |send_node|
            next unless persistence_call?(send_node)

            add_offense_for_node(send_node, callback_name)
          end
        end

        def add_offense_for_node(node, callback_name)
          method_name = node.method_name
          attribute = extract_attribute_name(node)

          message = format(
            MSG,
            attribute: attribute,
            method: method_name,
            callback: callback_name
          )

          add_offense(node, message: message)
        end

        def extract_attribute_name(node)
          # Try to extract from hash argument (e.g., update(name: 'foo'))
          if hash_argument?(node)
            key = first_hash_key(node)
            return key.to_s if key
          end

          # Try to extract from symbol argument (e.g., update_column(:name, 'foo'))
          symbol_arg = first_symbol_arg(node)
          return symbol_arg.to_s if symbol_arg

          'attribute'
        end
      end
    end
  end
end
