# frozen_string_literal: true

require "spec_helper"

RSpec.describe(GitHubPages::HealthCheck::Resolver) do
  let(:domain) { "www.example.com" }
  subject { described_class.new(domain) }

  it "uses authoritative NS servers to query A records" do
    expect(described_class.default_resolver).to \
      receive(:query).with(domain, Dnsruby::Types::NS).and_call_original
    expect(subject.send(:authoritative_resolver)).to \
      receive(:query).with(domain, Dnsruby::Types::A).and_call_original
    subject.query(Dnsruby::Types::A)
  end

  it "uses authoritative NS servers to query CAA records, but falls back" do
    expect(described_class.default_resolver).to \
      receive(:query).with(domain, Dnsruby::Types::NS).and_call_original
    expect(subject.send(:authoritative_resolver)).to \
      receive(:query).with(domain, Dnsruby::Types::CAA).and_call_original
    expect(described_class.default_resolver).to \
      receive(:query).with(domain, Dnsruby::Types::CAA).and_call_original
    subject.query(Dnsruby::Types::CAA)
  end

  it "uses authoritative NS servers to query MX records, but falls back" do
    expect(described_class.default_resolver).to \
      receive(:query).with(domain, Dnsruby::Types::NS).and_call_original
    expect(subject.send(:authoritative_resolver)).to \
      receive(:query).with(domain, Dnsruby::Types::MX).and_call_original
    expect(described_class.default_resolver).to \
      receive(:query).with(domain, Dnsruby::Types::MX).and_call_original
    subject.query(Dnsruby::Types::MX)
  end

  it "uses the default resolver for CNAME records" do
    expect(described_class.default_resolver).to \
      receive(:query).with(domain, Dnsruby::Types::NS).and_call_original
    expect(described_class.default_resolver).to \
      receive(:query).with(domain, Dnsruby::Types::CNAME).and_call_original
    expect(subject.send(:authoritative_resolver)).not_to receive(:query)
    subject.query(Dnsruby::Types::CNAME)
  end
end
