# frozen_string_literal: true

require "bundler/setup"
require "webmock/rspec"
require "pry-byebug"
require_relative "../lib/github-pages-health-check"

WebMock.disable_net_connect!

RSpec.configure do |config|
  config.raise_errors_for_deprecations!
  config.disable_monkey_patching!
  config.example_status_persistence_file_path = "spec/examples.txt"
  config.default_formatter = "doc" if config.files_to_run.one?
  config.order = :random
  Kernel.srand config.seed
end

def with_env(key, value)
  old_env = ENV[key]
  ENV[key] = value
  yield
  ENV[key] = old_env
end

def fixture_path(fixture = "")
  File.expand_path "./fixtures/#{fixture}", File.dirname(__FILE__)
end
