# frozen_string_literal: true

require "spec_helper"

RSpec.describe "justicecoin.org characterization test" do
  context "when given a domain of justicecoin.org" do
    it "successfully returns DNS results" do
      # Currently errors
      domain = GitHubPages::HealthCheck::Domain.new("justicecoin.org")
      aggregate_failures do
        expect(domain.resolver.query("A").first.to_s).to start_with("justicecoin.org.")
        expect(domain.resolver.query("CNAME").first.to_s).to eq("")
        expect(domain.resolver.query("MX").first.to_s).to start_with("justicecoin.org.")
        expect(domain.resolver.query("AAAA").first.to_s).to eq("")
      end
    end
  end

  context "when given a domain of github.com" do
    it "successfully returns DNS results" do
      domain = GitHubPages::HealthCheck::Domain.new("github.com")
      aggregate_failures do
        expect(domain.resolver.query("A").first.to_s).to start_with("github.com.")
        expect(domain.resolver.query("CNAME").first.to_s).to eq("")
        expect(domain.resolver.query("MX").first.to_s).to start_with("github.com.")
        expect(domain.resolver.query("AAAA").first.to_s).to eq("")
      end
    end
  end

  context "when given a domain of google.com" do
    it "successfully returns DNS results" do
      domain = GitHubPages::HealthCheck::Domain.new("google.com")
      aggregate_failures do
        expect(domain.resolver.query("A").first.to_s).to start_with("google.com.")
        expect(domain.resolver.query("CNAME").first.to_s).to eq("")
        expect(domain.resolver.query("MX").first.to_s).to start_with("google.com.")
        expect(domain.resolver.query("AAAA").first.to_s).to start_with("google.com.")
      end
    end
  end
end

