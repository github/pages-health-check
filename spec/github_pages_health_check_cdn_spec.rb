# frozen_string_literal: true
require 'spec_helper'
require 'json'
require 'tempfile'
require 'ipaddr'

describe(GitHubPages::HealthCheck::CDN) do
  let(:instance) { described_class.send(:new, path: ipaddr_path) }
  let(:tempfile) { Tempfile.new('pages-cdn-ips').tap { |f| f.sync = true } }
  let(:ipaddr_path) { tempfile.path }

  context 'default' do
    let(:instance) { described_class.instance }

    it 'loads the default config' do
      path = File.expand_path(instance.path)
      expected = File.expand_path('../config/cdn-ips.txt', File.dirname(__FILE__))
      expect(path).to eql(expected)
    end
  end

  context 'no config file' do
    before { tempfile.unlink }

    it 'raises an error' do
      expect { instance.send(:ranges) }.to raise_error 'no implicit conversion of nil into String'
    end
  end

  context 'parses config' do
    before { tempfile.write("199.27.128.0/21\n173.245.48.0/20") }

    it 'has two IPs' do
      expect(instance.send(:ranges).size).to eql(2)
    end

    it 'loads the IP addresses' do
      expect(instance.send(:ranges)).to include(IPAddr.new('199.27.128.0/21'))
      expect(instance.send(:ranges)).to include(IPAddr.new('173.245.48.0/20'))
    end

    it('controls? 199.27.128.55') { expect(instance.controls_ip?(IPAddr.new('199.27.128.55'))).to be_truthy }
    it('controls? 173.245.48.55') { expect(instance.controls_ip?(IPAddr.new('173.245.48.55'))).to be_truthy }
    it('controls? 200.27.128.55') { expect(instance.controls_ip?(IPAddr.new('200.27.128.55'))).to be_falsey }
  end

  { 'Fastly' => '151.101.32.133', 'CloudFlare' => '108.162.196.20' }.each do |service, ip|
    context service do
      it 'works as s singleton' do
        klass = Kernel.const_get("GitHubPages::HealthCheck::#{service}").send(:new)
        expect(klass.controls_ip?(ip)).to be(true)

        github_ip = GitHubPages::HealthCheck::Domain::CURRENT_IP_ADDRESSES.first
        expect(klass.controls_ip?(github_ip)).to be(false)
      end
    end
  end
end
