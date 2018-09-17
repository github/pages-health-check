# frozen_string_literal: true

require "spec_helper"

RSpec.describe(GitHubPages::HealthCheck::HTTPSDomain) do
  let(:domain) { "foo.github.io" }
  let(:cname) { domain }
  subject { described_class.new(domain) }
  let(:cname_packet) do
    Dnsruby::RR.create("#{domain}. 1000 IN CNAME #{cname}.")
  end
  let(:mx_packet) do
    Dnsruby::RR.create("#{domain}. 1000 IN MX 10 mail.example.com.")
  end
  let(:ip) { "127.0.0.1" }
  let(:a_packet) do
    Dnsruby::RR.create("#{domain}. 1000 IN A #{ip}")
  end
  let(:aaaa_packet) do
    Dnsruby::RR.create("#{domain}. 1000 IN AAAA #{ip6}")
  end
  let(:caa_domain) { "" }
  let(:caa_packet) do
    Dnsruby::RR.create("#{domain}. 1000 IN CAA 0 issue #{caa_domain.inspect}")
  end

  before(:each) do
    stub_request(:head, "http://#{domain}")
      .to_return(:status => 200, :headers => { "Server" => "GitHub.com" })
  end

  context "https eligibility" do
    context "A records pointed to old IPs" do
      let(:ip) { "192.30.252.153" }
      before(:each) { allow(subject).to receive(:dns) { [a_packet] } }
      before(:each) { allow(subject.send(:caa)).to receive(:query) { [a_packet] } }

      it { is_expected.not_to be_https_eligible }

      context "with unicode encoded domain" do
        let(:domain) { "dómain.example.com" }

        it { is_expected.not_to be_https_eligible }
      end

      context "with punycode encoded domain" do
        let(:domain) { "xn--dmain-0ta.example.com" }

        it { is_expected.not_to be_https_eligible }
      end
    end

    context "A records pointed to new IPs" do
      let(:ip) { "185.199.108.153" }
      before(:each) { allow(subject).to receive(:dns) { [a_packet] } }
      before(:each) { allow(subject.send(:caa)).to receive(:query) { [a_packet] } }

      it { is_expected.to be_https_eligible }

      context "with bad CAA records" do
        let(:caa_domain) { "digicert.com" }
        before(:each) { allow(subject.send(:caa)).to receive(:query) { [caa_packet] } }

        it { is_expected.not_to be_https_eligible }
      end

      context "with good CAA records" do
        let(:caa_domain) { "letsencrypt.org" }
        before(:each) { allow(subject.send(:caa)).to receive(:query) { [caa_packet] } }

        it { is_expected.to be_https_eligible }
      end

      context "with good additional A record" do
        let(:ip) { "185.199.109.153" }

        it { is_expected.to be_https_eligible }
      end

      context "with bad additional A record" do
        let(:ip) { "192.30.252.153" }

        it { is_expected.not_to be_https_eligible }
      end

      context "with unicode encoded domain" do
        let(:domain) { "dómain.example.com" }

        it { is_expected.to be_https_eligible }

        context "with bad CAA records" do
          let(:caa_domain) { "digicert.com" }
          before(:each) { allow(subject.send(:caa)).to receive(:query) { [caa_packet] } }

          it { is_expected.not_to be_https_eligible }
        end

        context "with good CAA records" do
          let(:caa_domain) { "letsencrypt.org" }
          before(:each) { allow(subject.send(:caa)).to receive(:query) { [caa_packet] } }

          it { is_expected.to be_https_eligible }
        end
      end

      context "with punycode encoded domain" do
        let(:domain) { "xn--dmain-0ta.example.com" }

        it { is_expected.to be_https_eligible }

        context "with bad CAA records" do
          let(:caa_domain) { "digicert.com" }
          before(:each) { allow(subject.send(:caa)).to receive(:query) { [caa_packet] } }

          it { is_expected.not_to be_https_eligible }
        end

        context "with good CAA records" do
          let(:caa_domain) { "letsencrypt.org" }
          before(:each) { allow(subject.send(:caa)).to receive(:query) { [caa_packet] } }

          it { is_expected.to be_https_eligible }
        end
      end
    end

    context "CNAME record pointed to username" do
      let(:cname) { "foobar.github.io" }
      before(:each) { allow(subject).to receive(:dns) { [cname_packet] } }
      before(:each) { allow(subject.send(:caa)).to receive(:query) { [cname_packet] } }

      it { is_expected.to be_https_eligible }

      context "with bad CAA records" do
        let(:caa_domain) { "digicert.com" }
        before(:each) { allow(subject.send(:caa)).to receive(:query) { [caa_packet] } }

        it { is_expected.not_to be_https_eligible }
      end

      context "with good CAA records" do
        let(:caa_domain) { "letsencrypt.org" }
        before(:each) { allow(subject.send(:caa)).to receive(:query) { [caa_packet] } }

        it { is_expected.to be_https_eligible }
      end

      context "with unicode encoded domain" do
        let(:domain) { "dómain.example.com" }

        it { is_expected.to be_https_eligible }

        context "with bad CAA records" do
          let(:caa_domain) { "digicert.com" }
          before(:each) { allow(subject.send(:caa)).to receive(:query) { [caa_packet] } }

          it { is_expected.not_to be_https_eligible }
        end

        context "with good CAA records" do
          let(:caa_domain) { "letsencrypt.org" }
          before(:each) { allow(subject.send(:caa)).to receive(:query) { [caa_packet] } }

          it { is_expected.to be_https_eligible }
        end
      end

      context "with punycode encoded domain" do
        let(:domain) { "xn--dmain-0ta.example.com" }

        it { is_expected.to be_https_eligible }

        context "with bad CAA records" do
          let(:caa_domain) { "digicert.com" }
          before(:each) { allow(subject.send(:caa)).to receive(:query) { [caa_packet] } }

          it { is_expected.not_to be_https_eligible }
        end

        context "with good CAA records" do
          let(:caa_domain) { "letsencrypt.org" }
          before(:each) { allow(subject.send(:caa)).to receive(:query) { [caa_packet] } }

          it { is_expected.to be_https_eligible }
        end
      end
    end

    context "CNAME record pointed elsewhere" do
      let(:cname) { "jinglebells.com" }
      before(:each) { allow(subject).to receive(:dns) { [cname_packet] } }
      before(:each) { allow(subject.send(:caa)).to receive(:query) { [cname_packet] } }

      it { is_expected.not_to be_https_eligible }

      context "with bad CAA records" do
        let(:caa_domain) { "digicert.com" }
        before(:each) { allow(subject.send(:caa)).to receive(:query) { [caa_packet] } }

        it { is_expected.not_to be_https_eligible }
      end

      context "with good CAA records" do
        let(:caa_domain) { "letsencrypt.org" }
        before(:each) { allow(subject.send(:caa)).to receive(:query) { [caa_packet] } }

        it { is_expected.not_to be_https_eligible }
      end

      context "with unicode encoded domain" do
        let(:domain) { "dómain.example.com" }

        it { is_expected.not_to be_https_eligible }
      end

      context "with punycode encoded domain" do
        let(:domain) { "xn--dmain-0ta.example.com" }

        it { is_expected.not_to be_https_eligible }
      end
    end
  end
end
