require "spec_helper"

RSpec.describe(GitHubPages::HealthCheck::RedundantCheck) do
  QueryResult = Struct.new(:answer)
  let(:domain) { "www.example.com" }
  let(:ns_packet) { Dnsruby::RR.create("#{domain}. 1000 IN NS art.ns.cloudflare.com.") }
  let(:good_cname_packet) { Dnsruby::RR.create("#{domain}. 100 IN CNAME parkr.github.io.") }
  let(:bad_cname_packet) { Dnsruby::RR.create("#{domain}. 100 IN CNAME pumpkineater.com.") }
  let(:default_nameserver_results) { [good_cname_packet] }
  let(:authoritative_nameserver_results) { nil }
  let(:public_nameserver_results) { nil }
  let(:server_header) { "GitHub.com" }
  subject { described_class.new(domain) }
  before(:each) do
    allow(GitHubPages::HealthCheck::Resolver.default_resolver).to \
      receive(:query).and_call_original
    allow(subject.send(:check_with_default_nameservers).resolver).to \
      receive(:query).and_return(default_nameserver_results)
    allow(subject.send(:check_with_default_nameservers).send(:caa)).to \
      receive(:query).and_return(default_nameserver_results)
    allow(GitHubPages::HealthCheck::Resolver.default_resolver).to \
      receive(:query).with(domain, Dnsruby::Types::NS).and_return(QueryResult.new([ns_packet]))
    allow(subject.send(:check_with_authoritative_nameservers).resolver).to \
      receive(:query).and_return(authoritative_nameserver_results)
    allow(subject.send(:check_with_public_nameservers).resolver).to \
      receive(:query).and_return(public_nameserver_results)
    stub_request(:head, "http://#{domain}/")
      .to_return(:status => 200, :body => "", :headers => { "Server" => server_header })
  end

  it { is_expected.to be_valid }
  it { is_expected.to be_https_eligible }

  it "has a link to the check which was most valid" do
    expect(subject.check.nameservers).to eq(:default)
    expect(subject.check).not_to be_nil
    expect(subject.check).to be_valid
  end

  context "when default nameservers fail us" do
    let(:default_nameserver_results) { [bad_cname_packet] }
    let(:authoritative_nameserver_results) { [good_cname_packet] }
    it { is_expected.to be_valid }
    it { is_expected.to be_https_eligible }

    it "falls back to the authoritative nameserver for HTTPS eligibility" do
      check = subject.send(:checks).find(&:https_eligible?)
      expect(check.nameservers).to eq(:authoritative)
    end
  end
end
