require 'spec_helper'
require 'json'

describe(GitHubPages::HealthCheck) do
  let(:health_check) { GitHubPages::HealthCheck.new("foo.github.io") }

  def a_packet(ip)
     Net::DNS::RR::A.new(:name => "pages.invalid", :address => ip, :ttl => 1000)
  end

  def cname_packet(domain)
    Net::DNS::RR::CNAME.new(:name => "pages.invalid", :cname => domain, :ttl => 1000)
  end

  it "knows old IP addresses" do
    %w[204.232.175.78 207.97.227.245].each do |ip_address|
      allow(health_check).to receive(:dns) { [a_packet(ip_address)] }
      expect(health_check.old_ip_address?).to be(true)
    end

    allow(health_check).to receive(:dns) { [a_packet("1.2.3.4")] }
    expect(health_check.old_ip_address?).to be(false)
  end

  it "knows when a domain is an A record" do
    allow(health_check).to receive(:dns) { [a_packet("1.2.3.4")] }
    expect(health_check.a_record?).to be(true)
    expect(health_check.cname_record?).to be(false)
  end

  it "known when a domain is a CNAME record" do
    allow(health_check).to receive(:dns) { [cname_packet("pages.github.com")] }
    expect(health_check.cname_record?).to be(true)
    expect(health_check.a_record?).to be(false)
  end

  it "knows what an apex domain is" do
    allow(health_check).to receive(:domain) { "parkermoore.de" }
    expect(health_check.apex_domain?).to be(true)

    allow(health_check).to receive(:domain) { "bbc.co.uk" }
    expect(health_check.apex_domain?).to be(true)
  end

  it "knows when the domain is on cloudflare" do
    allow(health_check).to receive(:dns) { [a_packet("108.162.196.20")] }
    expect(health_check.cloudflare_ip?).to be(true)

    allow(health_check).to receive(:dns) { [a_packet("1.1.1.1")] }
    expect(health_check.cloudflare_ip?).to be(false)
  end

  it "knows a subdomain is not an apex domain" do
    allow(health_check).to receive(:domain) { "blog.parkermoore.de" }
    expect(health_check.apex_domain?).to be(false)

    allow(health_check).to receive(:domain) { "www.bbc.co.uk" }
    expect(health_check.apex_domain?).to be(false)
  end

  it "knows what should be an apex record" do
    allow(health_check).to receive(:domain) { "parkermoore.de" }
    expect(health_check.should_be_a_record?).to be(true)

    allow(health_check).to receive(:domain) { "bbc.co.uk" }
    expect(health_check.should_be_a_record?).to be(true)

    allow(health_check).to receive(:domain) { "blog.parkermoore.de" }
    expect(health_check.should_be_a_record?).to be(false)

    allow(health_check).to receive(:domain) { "www.bbc.co.uk" }
    expect(health_check.should_be_a_record?).to be(false)

    allow(health_check).to receive(:domain) { "foo.github.io" }
    expect(health_check.should_be_a_record?).to be(false)

    allow(health_check).to receive(:domain) { "pages.github.com" }
    expect(health_check.should_be_a_record?).to be(false)
  end

  it "can determine a valid GitHub Pages CNAME value" do
    ["parkr.github.io", "mattr-.github.com"].each do |domain|
      allow(health_check).to receive(:dns) { [cname_packet(domain)] }
      expect(health_check.pointed_to_github_user_domain?).to be(true)
    end
    ["github.com", "ben.balter.com"].each do |domain|
      allow(health_check).to receive(:dns) { [cname_packet(domain)] }
      expect(health_check.pointed_to_github_user_domain?).to be(false)
    end
  end

  it "can determine when an apex domain is pointed at a GitHub Pages IP address" do
    allow(health_check).to receive(:domain) { "getbootstrap.com" }
    expect(health_check.pointed_to_github_pages_ip?).to be(true)
  end

  it "can determine when an apex domain is not pointed at a GitHub Pages IP address" do
    allow(health_check).to receive(:domain) { "example.com" }
    expect(health_check.pointed_to_github_pages_ip?).to be(false)
  end

  it "can determine that a subdomain with a CNAME record is not pointed at a GitHub Pages IP address" do
    allow(health_check).to receive(:domain) { "pages.github.com" }
    expect(health_check.pointed_to_github_pages_ip?).to be(false)
  end

  it "retrieves a site's dns record" do
    allow(health_check).to receive(:domain) { "pages.github.com" }
    expect(health_check.dns.first.class).to eql(Net::DNS::RR::CNAME)
  end

  it "can detect pages domains" do
    allow(health_check).to receive(:domain) { "pages.github.com" }
    expect(health_check.pages_domain?).to be(true)

    allow(health_check).to receive(:domain) { "pages.github.io" }
    expect(health_check.pages_domain?).to be(true)

    allow(health_check).to receive(:domain) { "pages.github.io." }
    expect(health_check.pages_domain?).to be(true)
  end

  it "doesn't detect non-pages domains as a pages domain" do
    allow(health_check).to receive(:domain) { "github.com" }
    expect(health_check.pages_domain?).to be(false)

    allow(health_check).to receive(:domain) { "google.co.uk" }
    expect(health_check.pages_domain?).to be(false)
  end

  it "detects invalid doimains" do
    allow(health_check).to receive(:domain) { "github.com" }
    expect(health_check.valid_domain?).to be(true)

    allow(health_check).to receive(:domain) { "github.invalid" }
    expect(health_check.valid_domain?).to be(false)
  end

  it "returns valid json" do
    data = JSON.parse GitHubPages::HealthCheck.new("benbalter.com").to_json
    expect(data.length).to eql(13)
    data.each { |key, value| expect([true,false,nil].include?(value)).to eql(true) }
  end

  it "return the error" do
    check = GitHubPages::HealthCheck.new "developer.facebook.com"
    expect(check.valid?).to eql(false)
    expect(check.reason.class).to eql(GitHubPages::HealthCheck::InvalidCNAME)
    expect(check.reason.message).to eql("CNAME does not point to GitHub Pages")
  end

  it "knows when a domain is served by pages" do
    check = GitHubPages::HealthCheck.new "chooosealicense.com"
    expect(check.valid?).to eql(true)
  end

  it "knows when a GitHub domain is served by pages" do
    check = GitHubPages::HealthCheck.new "mac.github.com"
    expect(check.valid?).to eql(true)
  end

  it "knows when a domain isn't served bt pages" do
    check = GitHubPages::HealthCheck.new "github.com"
    expect(check.valid?).to eql(false)
    expect(check.reason.class).to eql(GitHubPages::HealthCheck::NotServedByPages)
    expect(check.reason.message).to eql("Domain does not resolve to the GitHub Pages server")
  end

  it "knows when the domain is a github domain" do
    check = GitHubPages::HealthCheck.new "pages.github.com"
    expect(check.github_domain?).to eql(true)

    check = GitHubPages::HealthCheck.new "choosealicense.com"
    expect(check.github_domain?).to eql(false)

    check = GitHubPages::HealthCheck.new "benbalter.github.io"
    expect(check.github_domain?).to eql(false)
  end
end
