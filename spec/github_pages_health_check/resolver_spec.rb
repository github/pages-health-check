# frozen_string_literal: true

require "spec_helper"

RSpec.describe(GitHubPages::HealthCheck::Resolver) do
  let(:domain) { "example.com" }
  let(:nameservers) { :default }
  subject { described_class.new(domain, :nameservers => nameservers) }

  context "default" do
    it "uses the default resolver" do
      expect(subject.send(:recursor)).to \
        receive(:query).with(domain, Dnsruby::Types::A).and_call_original
      subject.query(Dnsruby::Types::A)
    end
  end

  context "authoritative" do
    let(:nameservers) { :authoritative }

    it "uses an authoritative resolver" do
      expect(described_class.default_resolver).to \
        receive(:query).with(domain, Dnsruby::Types::NS).and_call_original
      expect(subject.send(:recursor)).to \
        receive(:query).with(domain, Dnsruby::Types::A).and_call_original
      subject.query(Dnsruby::Types::A)
    end
  end

  context "custom" do
    let(:nameservers) { ["8.8.8.8", "8.8.4.4"] }

    it "uses the custom resolver" do
      expect(subject.send(:resolver).config.nameserver).to eq(nameservers)
      expect(subject.send(:recursor)).to \
        receive(:query).with(domain, Dnsruby::Types::A).and_call_original
      subject.query(Dnsruby::Types::A)
    end
  end
end
