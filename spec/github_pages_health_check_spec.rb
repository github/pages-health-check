# frozen_string_literal: true

require "spec_helper"

RSpec.describe(GitHubPages::HealthCheck) do
  let(:domain) { "pages.github.com" }
  before(:each) do
    stub_request(:head, "https://#{domain}/")
      .to_return(:status => 200, :body => "", :headers => { "Server" => "GitHub.com" })
  end

  it "checks" do
    check = GitHubPages::HealthCheck.check(domain)
    expect(check.class).to eql(GitHubPages::HealthCheck::Site)
    expect(check.domain.host).to eql(domain)
  end

  it "sets a network proxy url" do
    expect(GitHubPages::HealthCheck.typhoeus_options).to include(:proxy => nil)
    GitHubPages::HealthCheck.set_proxy("http://proxy.org")
    expect(GitHubPages::HealthCheck.typhoeus_options).to include(:proxy => "http://proxy.org")
  end
end
