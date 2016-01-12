require "spec_helper"
require "json"
require "tempfile"
require "ipaddr"

describe(GitHubPages::HealthCheck::CloudFlare) do

  let(:instance) { GitHubPages::HealthCheck::CloudFlare.send(:new, :path => ipaddr_path)  }
  let(:tempfile) { Tempfile.new("pages-jekyll-alarmist-cloudflare-ips").tap { |f| f.sync = true } }
  let(:ipaddr_path) { tempfile.path }

  context "default" do
    let(:instance) { GitHubPages::HealthCheck::CloudFlare.instance }

    it "loads the default config" do
      path = File.expand_path(instance.path)
      expected = File.expand_path("../config/cloudflare-ips.txt", File.dirname(__FILE__))
      expect(path).to eql(expected)
    end
  end

  context "no config file" do
    before { tempfile.unlink }

    it "raises an error" do
      expect { instance.ranges }.to raise_error "no implicit conversion of nil into String"
    end
  end

  context "parses config" do
    before { tempfile.write("199.27.128.0/21\n173.245.48.0/20") }

    it "has two IPs" do
      expect(instance.ranges.size).to eql(2)
    end

    it "loads the IP addresses" do
      expect(instance.ranges).to include(IPAddr.new("199.27.128.0/21"))
      expect(instance.ranges).to include(IPAddr.new("173.245.48.0/20"))
    end

    it("controls? 199.27.128.55") { expect(instance.controls_ip?(IPAddr.new("199.27.128.55"))).to be_truthy }
    it("controls? 173.245.48.55") { expect(instance.controls_ip?(IPAddr.new("173.245.48.55"))).to be_truthy }
    it("controls? 200.27.128.55") { expect(instance.controls_ip?(IPAddr.new("200.27.128.55"))).to be_falsey }
  end

  it "works as a singleton" do
    expect(GitHubPages::HealthCheck::CloudFlare.controls_ip?("108.162.196.20")).to be(true)
  end
end
