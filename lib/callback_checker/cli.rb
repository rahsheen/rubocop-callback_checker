# frozen_string_literal: true

require_relative 'prism_analyzer'
require_relative '../rubocop/callback_checker/version'
require 'optparse'

module CallbackChecker
  VERSION = RuboCop::CallbackChecker::VERSION

  class CLI
    def self.run(argv)
      new(argv).run
    end

    def initialize(argv)
      @argv = argv
      @paths = []
      @options = {}
    end

    def run
      parse_options

      if @paths.empty?
        puts 'Usage: rubocop-callback-checker [options] FILE...'
        puts "Try 'rubocop-callback-checker --help' for more information."
        return 1
      end

      files = collect_files(@paths)

      if files.empty?
        puts 'No Ruby files found to analyze.'
        return 1
      end

      total_offenses = 0

      files.each do |file|
        offenses = PrismAnalyzer.analyze_file(file)

        if offenses.any?
          total_offenses += offenses.size
          print_offenses(file, offenses)
        end
      end

      print_summary(files.size, total_offenses)

      total_offenses.positive? ? 1 : 0
    end

    private

    def parse_options
      OptionParser.new do |opts|
        opts.banner = 'Usage: rubocop-callback-checker [options] FILE...'

        opts.on('-h', '--help', 'Print this help') do
          puts opts
          exit 0
        end

        opts.on('-v', '--version', 'Print version') do
          puts "rubocop-callback-checker version #{VERSION}"
          exit 0
        end
      end.parse!(@argv)

      @paths = @argv
    end

    def collect_files(paths)
      files = []

      paths.each do |path|
        if File.file?(path)
          files << path if path.end_with?('.rb')
        elsif File.directory?(path)
          files.concat(Dir.glob(File.join(path, '**', '*.rb')))
        else
          warn "Warning: #{path} is not a file or directory"
        end
      end

      files
    end

    def print_offenses(file, offenses)
      puts "\n#{file}"

      offenses.each do |offense|
        location = offense[:location]
        puts "  #{location[:start_line]}:#{location[:start_column]}: #{offense[:message]}"
        puts "    #{offense[:code]}"
      end
    end

    def print_summary(file_count, offense_count)
      puts "\n#{'=' * 80}"
      puts "#{file_count} file(s) inspected, #{offense_count} offense(s) detected"
    end
  end
end
