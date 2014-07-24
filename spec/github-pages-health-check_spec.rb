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
      health_check.stub(:dns) { [a_packet(ip_address)] }
      expect(health_check.old_ip_address?).to be_true
    end

    health_check.stub(:dns) { [a_packet("1.2.3.4")] }
    expect(health_check.old_ip_address?).to be_false
  end

  it "knows when a domain is an A record" do
    health_check.stub(:dns) { [a_packet("1.2.3.4")] }
    expect(health_check.a_record?).to be_true
    expect(health_check.cname_record?).to be_false
  end

  it "known when a domain is a CNAME record" do
    health_check.stub(:dns) { [cname_packet("pages.github.com")] }
    expect(health_check.cname_record?).to be_true
    expect(health_check.a_record?).to be_false
  end

  it "knows what an apex domain is" do
    health_check.stub(:domain) { "parkermoore.de" }
    expect(health_check.apex_domain?).to be_true

    health_check.stub(:domain) { "bbc.co.uk" }
    expect(health_check.apex_domain?).to be_true
  end

  it "knows when the domain is on cloudflare" do
    health_check.stub(:dns) { [a_packet("108.162.196.20")] }
    expect(health_check.cloudflare_ip?).to be_true

    health_check.stub(:dns) { [a_packet("1.1.1.1")] }
    expect(health_check.cloudflare_ip?).to be_false
  end

  it "knows a subdomain is not an apex domain" do
    health_check.stub(:domain) { "blog.parkermoore.de" }
    expect(health_check.apex_domain?).to be_false

    health_check.stub(:domain) { "www.bbc.co.uk" }
    expect(health_check.apex_domain?).to be_false
  end

  it "knows what should be an apex record" do
    health_check.stub(:domain) { "parkermoore.de" }
    expect(health_check.should_be_a_record?).to be_true

    health_check.stub(:domain) { "bbc.co.uk" }
    expect(health_check.should_be_a_record?).to be_true

    health_check.stub(:domain) { "blog.parkermoore.de" }
    expect(health_check.should_be_a_record?).to be_false

    health_check.stub(:domain) { "www.bbc.co.uk" }
    expect(health_check.should_be_a_record?).to be_false

    health_check.stub(:domain) { "foo.github.io" }
    expect(health_check.should_be_a_record?).to be_false

    health_check.stub(:domain) { "pages.github.com" }
    expect(health_check.should_be_a_record?).to be_false
  end

  it "can determine a valid GitHub Pages CNAME value" do
    ["parkr.github.io", "mattr-.github.com"].each do |domain|
      health_check.stub(:dns) { [cname_packet(domain)] }
      expect(health_check.pointed_to_github_user_domain?).to be_true
    end
    ["github.com", "ben.balter.com"].each do |domain|
      health_check.stub(:dns) { [cname_packet(domain)] }
      expect(health_check.pointed_to_github_user_domain?).to be_false
    end
  end

  it "retrieves a site's dns record" do
    health_check.stub(:domain) { "pages.github.com" }
    expect(health_check.dns.first.class).to eql(Net::DNS::RR::CNAME)
  end

  it "can detect pages domains" do
    health_check.stub(:domain) { "pages.github.com" }
    expect(health_check.pages_domain?).to be_true

    health_check.stub(:domain) { "pages.github.io" }
    expect(health_check.pages_domain?).to be_true

    health_check.stub(:domain) { "pages.github.io." }
    expect(health_check.pages_domain?).to be_true
  end

  it "doesn't detect non-pages domains as a pages domain" do
    health_check.stub(:domain) { "github.com" }
    expect(health_check.pages_domain?).to be_false

    health_check.stub(:domain) { "google.co.uk" }
    expect(health_check.pages_domain?).to be_false
  end

  it "detects invalid doimains" do
    health_check.stub(:domain) { "github.com" }
    expect(health_check.valid_domain?).to be_true

    health_check.stub(:domain) { "github.invalid" }
    expect(health_check.valid_domain?).to be_false
  end

  it "returns valid json" do
    data = JSON.parse GitHubPages::HealthCheck.new("benbalter.com").to_json
    expect(data.length).to eql(10)
    data.each { |key, value| expect([true,false].include?(value)).should eql(true) }
  end

end
