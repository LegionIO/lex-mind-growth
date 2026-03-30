# frozen_string_literal: true

source 'https://rubygems.org'
gemspec

group :test do
  gem 'rake'
  gem 'rspec', '~> 3.13'
  gem 'rspec_junit_formatter'
  gem 'rubocop', '~> 1.75'
  gem 'rubocop-legion', '~> 0.1.7'
  gem 'rubocop-rspec'
  gem 'simplecov'
end

gem 'legion-gaia', path: '../../legion-gaia' if File.directory?(File.expand_path('../../legion-gaia', __dir__))
gem 'legion-llm', path: '../../legion-llm', require: false if File.directory?(File.expand_path('../../legion-llm', __dir__))
gem 'lex-codegen', path: '../../extensions-core/lex-codegen', require: false if File.directory?(File.expand_path('../../extensions-core/lex-codegen', __dir__))
gem 'lex-exec', path: '../../extensions-core/lex-exec', require: false if File.directory?(File.expand_path('../../extensions-core/lex-exec', __dir__))
