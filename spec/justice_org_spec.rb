# frozen_string_literal: true

require "spec_helper"

RSpec.describe "justicecoin.org characterization test" do
  context "when given a domain of justicecoin.org" do
    it "returns an empty array for AAAA queries" do
      # Currently errors
      domain = GitHubPages::HealthCheck::Domain.new("justicecoin.org")
      expect(domain.resolver.query("AAAA").to_a).to eq([])
    end
  end

  context "when given a domain of github.com" do
    it "returns an empty array for AAAA queries" do
      domain = GitHubPages::HealthCheck::Domain.new("github.com")
      expect(domain.resolver.query("AAAA").to_a).to eq([])
    end
  end
end

