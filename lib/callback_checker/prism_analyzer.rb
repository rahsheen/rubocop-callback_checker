# frozen_string_literal: true

require 'prism'

module CallbackChecker
  class PrismAnalyzer < Prism::Visitor
    attr_reader :offenses

    SIDE_EFFECT_SENSITIVE_CALLBACKS = %i[
      before_validation before_save after_save
      before_create after_create
      before_update after_update
      before_destroy after_destroy
      around_save around_create around_update around_destroy
    ].freeze

    SAFE_CALLBACKS = %i[
      after_commit after_create_commit after_update_commit
      after_destroy_commit after_save_commit after_rollback
    ].freeze

    SUSPICIOUS_CONSTANTS = %w[
      RestClient Faraday HTTParty Net Sidekiq ActionCable
    ].freeze

    SIDE_EFFECT_METHODS = %i[
      deliver_later deliver_now perform_later broadcast_later
      save save! update update! destroy destroy! create create!
      delete delete_all destroy_all update_all update_columns touch
    ].freeze

    def initialize(source)
      @source = source
      @offenses = []
      @current_class = nil
      @callback_methods = {}
      @current_callback_type = nil
    end

    def visit_class_node(node)
      previous_class = @current_class
      previous_methods = @callback_methods.dup

      @current_class = node
      @callback_methods = {}

      # First pass: collect all method definitions
      collect_methods(node)

      # Second pass: check callbacks
      super

      @current_class = previous_class
      @callback_methods = previous_methods
    end

    def visit_call_node(node)
      if callback_declaration?(node)
        check_callback(node)
      elsif @current_callback_type && side_effect_call?(node)
        add_offense(node, @current_callback_type)
      end

      super
    end

    def visit_if_node(node)
      # Make sure we visit all branches of conditionals
      super
    end

    def visit_unless_node(node)
      # Make sure we visit all branches of unless statements
      super
    end

    private

    def collect_methods(class_node)
      class_node.body&.body&.each do |statement|
        if statement.is_a?(Prism::DefNode)
          @callback_methods[statement.name] = statement
        end
      end
    end

    def callback_declaration?(node)
      return false unless node.receiver.nil?
      return false unless node.name

      callback_name = node.name
      SIDE_EFFECT_SENSITIVE_CALLBACKS.include?(callback_name) ||
        SAFE_CALLBACKS.include?(callback_name)
    end

    def check_callback(node)
      callback_name = node.name

      # Skip safe callbacks
      return if SAFE_CALLBACKS.include?(callback_name)

      if node.block
        # Block form: before_save do ... end
        check_block_callback(node, callback_name)
      elsif node.arguments
        # Symbol form: before_save :method_name
        check_symbol_callback(node, callback_name)
      end
    end

    def check_block_callback(node, callback_name)
      previous_callback = @current_callback_type
      @current_callback_type = callback_name

      visit(node.block)

      @current_callback_type = previous_callback
    end

    def check_symbol_callback(node, callback_name)
      return unless node.arguments&.arguments

      node.arguments.arguments.each do |arg|
        next unless arg.is_a?(Prism::SymbolNode)

        method_name = arg.value
        method_def = @callback_methods[method_name.to_sym]

        next unless method_def

        check_method_for_side_effects(method_def, callback_name)
      end
    end

    def check_method_for_side_effects(method_node, callback_name)
      previous_callback = @current_callback_type
      @current_callback_type = callback_name

      visit(method_node.body) if method_node.body

      @current_callback_type = previous_callback
    end

    def side_effect_call?(node)
      return false unless node.is_a?(Prism::CallNode)

      # Check for suspicious constant calls (RestClient.get, etc.)
      if node.receiver.is_a?(Prism::ConstantReadNode)
        constant_name = node.receiver.name.to_s
        return true if SUSPICIOUS_CONSTANTS.include?(constant_name)
        
        # Check for any constant that isn't a known safe pattern
        # This catches things like NewsletterSDK, CustomAPI, etc.
        return true if constant_appears_to_be_external_service?(constant_name)
      end

      # Check for side effect methods
      method_name = node.name
      return true if SIDE_EFFECT_METHODS.include?(method_name)

      # Check for mailer patterns (anything ending with Mailer)
      if node.receiver.is_a?(Prism::ConstantReadNode)
        constant_name = node.receiver.name.to_s
        return true if constant_name.end_with?('Mailer')
      end

      # Check for method chains that end with deliver_now
      if method_name == :deliver_now && node.receiver.is_a?(Prism::CallNode)
        return true
      end

      # Check for calls on associations or other objects (not self)
      if node.receiver && !self_reference?(node.receiver)
        return true if persistence_method?(method_name)
      end

      # Check for save/update on self or implicit self
      if node.receiver.nil? || self_reference?(node.receiver)
        return true if %i[save save! update update!].include?(method_name)
      end

      false
    end

    def constant_appears_to_be_external_service?(constant_name)
      # Heuristic: if it's all caps or ends with SDK, API, Client, Service
      # it's probably an external service
      return true if constant_name.end_with?('SDK', 'API', 'Client', 'Service')
      return true if constant_name == constant_name.upcase && constant_name.length > 1
      
      false
    end

    def self_reference?(node)
      node.is_a?(Prism::SelfNode)
    end

    def persistence_method?(method_name)
      %i[
        save save! update update! destroy destroy! create create!
        delete delete_all destroy_all update_all update_columns touch
      ].include?(method_name)
    end

    def add_offense(node, callback_type)
      location = node.location
      start_line = location.start_line
      start_column = location.start_column
      end_line = location.end_line
      end_column = location.end_column

      # Extract the source code for this node
      source_range = location.start_offset...location.end_offset
      code = @source[source_range]

      @offenses << {
        message: "Avoid side effects (API calls, mailers, background jobs, or modifying other records) in #{callback_type}. Use `after_commit` instead.",
        location: {
          start_line: start_line,
          start_column: start_column,
          end_line: end_line,
          end_column: end_column
        },
        code: code,
        callback_type: callback_type
      }
    end

    class << self
      def analyze_file(path)
        source = File.read(path)
        analyze_source(source, path)
      end

      def analyze_source(source, path = nil)
        result = Prism.parse(source)

        if result.errors.any?
          warn "Parse errors in #{path}:" if path
          result.errors.each do |error|
            warn "  #{error.message}"
          end
          return []
        end

        analyzer = new(source)
        analyzer.visit(result.value)
        analyzer.offenses
      end
    end
  end
end
