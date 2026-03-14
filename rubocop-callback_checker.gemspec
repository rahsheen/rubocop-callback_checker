# frozen_string_literal: true

require_relative 'lib/rubocop/callback_checker/version'

Gem::Specification.new do |spec|
  spec.name = 'rubocop-callback_checker'
  spec.version = RuboCop::CallbackChecker::VERSION
  spec.authors = ['rahsheen']
  spec.email = ['rahsheen.porter@gmail.com']

  spec.summary = 'rubocop '
  spec.description = 'A RuboCop extension focused on avoiding callback hell in Rails.'
  spec.homepage = 'https://github.com/rahsheen/rubocop-callback_checker'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.1.0'

  spec.metadata['allowed_push_host'] = 'https://rubygems.org'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = 'exe'
  spec.executables = ['rubocop-callback-checker']
  spec.require_paths = ['lib']

  # Uncomment to register a new dependency of your gem
  spec.add_dependency 'rubocop', '~> 1.0'
  spec.add_dependency 'rubocop-ast', '~> 1.0'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'rubocop-rails', '~> 2.0'
  spec.add_development_dependency 'rubocop-rake', '~> 0.7'
  spec.add_development_dependency 'rubocop-rspec', '~> 2.0'

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
