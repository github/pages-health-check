require 'spec_helper'
require 'json'

describe(GitHubPages::HealthCheck::CloudFlare) do

  let(:instance) { GitHubPages::HealthCheck::CloudFlare.instance }

  it "loads the IPs" do
    expect(instance.ranges.size).to eql(13)
  end

  it "detects a cloudflare IP" do
    expect(instance.controls_ip?("108.162.196.20")).to be(true)
  end

  it "doesn't return false positives" do
    expect(instance.controls_ip?("1.1.1.1")).to be(false)
  end

  it "works as a singleton" do
    expect(GitHubPages::HealthCheck::CloudFlare.controls_ip?("108.162.196.20")).to be(true)
  end
end
