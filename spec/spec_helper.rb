# frozen_string_literal: true
require "bundler/setup"
require "webmock/rspec"
require_relative "../lib/github-pages-health-check"

WebMock.disable_net_connect!

RSpec.configure do |config|
  config.raise_errors_for_deprecations!
  config.run_all_when_everything_filtered = true
  config.filter_run :focus
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
