# frozen_string_literal: true
require "spec_helper"
require "json"
require "tempfile"
require "ipaddr"

describe(GitHubPages::HealthCheck::CDN) do
  subject { described_class.instance }

  it "loads the default config" do
    path = File.expand_path(subject.path)
    relative_path = "../../config/cdn-ips.txt"
    expected = File.expand_path(relative_path, File.dirname(__FILE__))
    expect(path).to eql(expected)
  end

  context "with the IP file stubbed" do
    let(:tempfile) { Tempfile.new("pages-cdn-ips").tap { |f| f.sync = true } }
    let(:ipaddr_path) { tempfile.path }
    subject { described_class.send(:new, :path => ipaddr_path) }

    context "no config file" do
      before { tempfile.unlink }

      it "raises an error" do
        error = "no implicit conversion of nil into String"
        expect { subject.send(:ranges) }.to raise_error error
      end
    end

    context "parses config" do
      before { tempfile.write("199.27.128.0/21\n173.245.48.0/20") }

      it "has two IPs" do
        expect(subject.send(:ranges).size).to eql(2)
      end

      it "loads the IP addresses" do
        expect(subject.send(:ranges)).to include(IPAddr.new("199.27.128.0/21"))
        expect(subject.send(:ranges)).to include(IPAddr.new("173.245.48.0/20"))
      end

      it("controls? 199.27.128.55") do
        expect(subject.controls_ip?(IPAddr.new("199.27.128.55"))).to be_truthy
      end

      it("controls? 173.245.48.55") do
        expect(subject.controls_ip?(IPAddr.new("173.245.48.55"))).to be_truthy
      end

      it("controls? 200.27.128.55") do
        expect(subject.controls_ip?(IPAddr.new("200.27.128.55"))).to be_falsey
      end
    end

    {
      "Fastly" => "151.101.32.133",
      "CloudFlare" => "108.162.196.20"
    }.each do |service, ip|
      context service do
        it "works as s singleton" do
          const = "GitHubPages::HealthCheck::#{service}"
          klass = Kernel.const_get(const).send(:new)
          expect(klass.controls_ip?(ip)).to be(true)

          github_ips = GitHubPages::HealthCheck::Domain::CURRENT_IP_ADDRESSES
          expect(klass.controls_ip?(github_ips.first)).to be(false)
        end
      end
    end
  end
end
