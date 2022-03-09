# frozen_string_literal: true

require "spec_helper"
require "json"
require "tempfile"
require "ipaddr"

RSpec.describe(GitHubPages::HealthCheck::CDN) do
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
      before { tempfile.write("199.27.128.0/21\n173.245.48.0/20\n2400:cb00::/32") }

      it "has three IPs" do
        expect(subject.send(:ranges).size).to eql(3)
      end

      it "loads the IP addresses" do
        expect(subject.send(:ranges)).to include(IPAddr.new("199.27.128.0/21"))
        expect(subject.send(:ranges)).to include(IPAddr.new("173.245.48.0/20"))
        expect(subject.send(:ranges)).to include(IPAddr.new("2400:cb00::/32"))
      end

      it("controls? 199.27.128.55") do
        expect(subject.controls_ip?(IPAddr.new("199.27.128.55"))).to be_truthy
      end

      it("controls? 173.245.48.55") do
        expect(subject.controls_ip?(IPAddr.new("173.245.48.55"))).to be_truthy
      end

      it("controls? 2400:cb00:1000:2000:3000:4000:5000:6000") do
        expect(
          subject.controls_ip?(
            IPAddr.new("2400:cb00:1000:2000:3000:4000:5000:6000")
          )
        ).to be_truthy
      end

      it("controls? 200.27.128.55") do
        expect(subject.controls_ip?(IPAddr.new("200.27.128.55"))).to be_falsy
      end
    end

    {
      "Fastly" => {
        :valid_ips => ["151.101.32.133", "2a04:4e40:1000:2000:3000:4000:5000:6000"],
        :invalid_ips => ["108.162.196.20", "2400:cb00:7000:8000:9000:A000:B000:C000"]
      },
      "CloudFlare" => {
        :valid_ips => ["108.162.196.20", "2400:cb00:7000:8000:9000:A000:B000:C000"],
        :invalid_ips => ["151.101.32.133", "2a04:4e40:1000:2000:3000:4000:5000:6000"]
      }
    }.each do |service, ips|
      context service do
        it "works as a singleton" do
          const = "GitHubPages::HealthCheck::#{service}"
          klass = Kernel.const_get(const).send(:new)

          ips[:valid_ips].each do |ip|
            expect(klass.controls_ip?(ip)).to eq(true), ip
          end

          ips[:invalid_ips].each do |ip|
            expect(klass.controls_ip?(ip)).to eq(false), ip
          end

          github_ips = GitHubPages::HealthCheck::Domain::CURRENT_IP_ADDRESSES
          expect(klass.controls_ip?(github_ips.first)).to be(false)
        end
      end
    end
  end
end
