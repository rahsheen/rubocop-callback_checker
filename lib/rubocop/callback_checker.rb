# frozen_string_literal: true

require_relative "callback_checker/version"
require "pathname"
require "yaml"

# Load all the cops
Dir[Pathname.new(__dir__).join("cop", "callback_checker", "**", "*.rb")].sort.each { |file| require file }

module Rubocop
  module CallbackChecker
    class Error < StandardError; end

    PROJECT_ROOT = Pathname.new(__dir__).parent.parent.freeze
    CONFIG_DEFAULT = PROJECT_ROOT.join("config", "default.yml").freeze

    def self.version
      VERSION
    end
  end
end
