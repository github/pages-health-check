# frozen_string_literal: true
require "spec_helper"

RSpec.describe(GitHubPages::HealthCheck) do
  it "checks" do
    check = GitHubPages::HealthCheck.check("pages.github.com")
    expect(check.class).to eql(GitHubPages::HealthCheck::Site)
    expect(check.domain.host).to eql("pages.github.com")
  end
end
