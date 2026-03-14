# frozen_string_literal: true

require_relative 'callback_checker/version'
require 'pathname'

module RuboCop
  module CallbackChecker
    class Error < StandardError; end

    PROJECT_ROOT = Pathname.new(__dir__).parent.parent.freeze
    CONFIG_DEFAULT = PROJECT_ROOT.join('config', 'default.yml').freeze

    # Inject the plugin's default configuration into RuboCop
    ::RuboCop::ConfigLoader.inject_defaults!(CONFIG_DEFAULT.to_s)
  end
end
