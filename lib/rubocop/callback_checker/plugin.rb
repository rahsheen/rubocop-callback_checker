# frozen_string_literal: true

require 'lint_roller'

module RuboCop
  module CallbackChecker
    # A plugin that integrates RuboCop CallbackChecker with RuboCop's plugin system.
    class Plugin < LintRoller::Plugin
      def about
        LintRoller::About.new(
          name: 'rubocop-callback_checker',
          version: VERSION,
          homepage: 'https://github.com/rahsheen/rubocop-callback_checker',
          description: 'A RuboCop extension focused on avoiding callback hell in Rails.'
        )
      end

      def supported?(context)
        context.engine == :rubocop
      end

      def rules(_context)
        LintRoller::Rules.new(
          type: :path,
          config_format: :rubocop,
          value: Pathname.new(__dir__).join('../../../config/default.yml')
        )
      end
    end
  end
end
