# frozen_string_literal: true

require "spec_helper"

RSpec.describe(GitHubPages::HealthCheck::Errors) do
  it "returns the errors" do
    expect(GitHubPages::HealthCheck::Errors.all.count).to eql(10)
  end
end
