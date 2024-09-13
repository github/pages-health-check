# frozen_string_literal: true

require "spec_helper"

RSpec.describe(GitHubPages::HealthCheck::Domain) do
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
  let(:ip6) { "::1" }
  let(:aaaa_packet) do
    Dnsruby::RR.create("#{domain}. 1000 IN AAAA #{ip6}")
  end
  let(:caa_domain) { "" }
  let(:caa_packet) do
    Dnsruby::RR.create("#{domain}. 1000 IN CAA 0 issue #{caa_domain.inspect}")
  end
  let(:soa_packet) do
    Dnsruby::RR.create("#{domain}. 1000 IN SOA ns.example.com. #{domain.inspect}")
  end
  let(:ns_packet) do
    Dnsruby::RR.create("#{domain}. 1000 IN NS ns.example.com.")
  end

  context "constructor" do
    it "can handle bare domains" do
      expect(subject.host).to eql(domain)
    end

    context "schemes" do
      %w(http https ftp).each do |scheme|
        context scheme do
          subject do
            described_class.new("#{scheme}://#{domain}")
          end

          it "parses the domain" do
            expect(subject.host).to eql(domain)
          end
        end
      end
    end

    context "paths" do
      ["/im-a-path", "/im-a-path/", "/index.html"].each do |path|
        context path do
          subject do
            described_class.new("http://#{domain}/#{path}")
          end

          it "parses the domain" do
            expect(subject.host).to eql(domain)
          end
        end
      end
    end

    context "stripping whitespace" do
      subject do
        described_class.new(" #{domain} ")
      end

      it "parses the domain" do
        expect(subject.host).to eql(domain)
      end
    end

    context "FQDNs" do
      subject do
        described_class.new("#{domain}.")
      end

      it "parses the domain" do
        expect(subject.host).to eql(domain)
      end
    end

    context "invalid domains" do
      let(:error) { GitHubPages::HealthCheck::Errors::InvalidDomainError }

      context "when given http://@" do
        let(:domain) { "http://@" }

        it "doesn't blow up" do
          expect(subject.host).to be_nil
          expect(subject.reason).to be_a(error)
        end
      end

      context "when given //" do
        let(:domain) { "//" }

        it "doesn't blow up" do
          expect(subject.host).to be_nil
          expect(subject.reason).to be_a(error)
        end
      end
    end
  end

  context "response" do
    let(:proxy) { "http://proxy.org:5000" }
    before do
      GitHubPages::HealthCheck.set_proxy(proxy)
    end
    after do
      GitHubPages::HealthCheck.set_proxy(nil)
    end

    it "uses a network proxy for outgoing requests" do
      stub_request(:head, domain).to_return(:status => 200, :headers => {})
      response = GitHubPages::HealthCheck::Domain.new(domain).send(:response)
      expect(response.request.options).to include(:proxy => proxy)
    end
  end

  context "A records" do
    before(:each) { allow(subject).to receive(:dns) { [a_packet] } }

    context "old IP addresses" do
      %w(204.232.175.78 207.97.227.245 192.30.252.153 192.30.252.154).each do |ip_address|
        context ip_address do
          let(:ip) { ip_address }

          it "knows it's a deprecated IP" do
            expect(subject).to be_a_old_ip_address
            expect(subject).to be_a_deprecated_ip
          end
        end
      end

      %w(185.199.108.153 185.199.109.153 185.199.110.153
         185.199.111.153).each do |ip_address|
        context ip_address do
          let(:ip) { ip_address }

          it "knows it's not an old IP" do
            expect(subject).not_to be_a_old_ip_address
            expect(subject).not_to be_a_deprecated_ip
            expect(subject).to be_pointed_to_github_pages_ip
          end
        end
      end

      context "a random IP" do
        let(:ip) { "1.2.3.4" }

        it "knows it's not an old IP" do
          expect(subject).to_not be_a_old_ip_address
        end
      end

      it "doesn't list current IPs as deprecated" do
        deprecated = GitHubPages::HealthCheck::Domain::LEGACY_IP_ADDRESSES
        GitHubPages::HealthCheck::Domain::CURRENT_IP_ADDRESSES.each do |ip|
          expect(deprecated).to_not include(ip)
        end
      end
    end

    it "knows when a domain is an A record" do
      expect(subject).to be_an_a_record
      expect(subject).to_not be_a_cname_record
    end

    it "knows when a domain has an invalid A record" do
      expect(subject).to be_an_a_record
      expect(subject).to be_a_valid_domain
      expect(subject.should_be_a_record?).to be_falsy
      expect(subject).to be_a_invalid_a_record
    end
  end

  context "AAAA records" do
    before(:each) { allow(subject).to receive(:dns) { [aaaa_packet] } }

    it "knows when a domain is an AAAA record" do
      expect(subject).to be_an_aaaa_record_present
      expect(subject).to_not be_a_cname_record
    end

    it "knows when a domain has an invalid AAAA record" do
      expect(subject).to be_an_aaaa_record_present
      expect(subject).to be_a_valid_domain
      expect(subject.should_be_a_record?).to eq(false)
      expect(subject).to be_a_invalid_aaaa_record
    end
  end

  context "A & AAAA recursive resolutions" do
    let(:domain) { "domain.com" }
    let(:cname) { "domain.github.io" }
    before(:each) do
      allow(subject).to receive(:dns) {
        [
          cname_packet,
          Dnsruby::RR.create("#{cname}. 1000 IN A #{ip}"),
          Dnsruby::RR.create("#{cname}. 1000 IN AAAA #{ip6}")
        ]
      }
    end

    it "does not get tricked by recursive resolution" do
      expect(subject).to_not be_an_aaaa_record_present
      expect(subject).to_not be_an_a_record_present
    end
  end

  context "CNAMEs" do
    before(:each) { allow(subject).to receive(:dns) { [cname_packet] } }

    it "known when a domain is a CNAME record" do
      expect(subject).to be_a_cname_record
      expect(subject).to_not be_an_a_record
    end

    context "multiple CNAMEs" do
      let(:cname) { "github.example.com" }
      before do
        allow(subject).to receive(:dns) do
          [
            cname_packet,
            Dnsruby::RR.create("#{cname}. 1000 IN CNAME example.github.io."),
            Dnsruby::RR.create("example.github.io 1000 IN A 192.168.0.1")
          ]
        end
      end

      it "follows the CNAMEs all the way down" do
        expect(subject.cname.host).to eq("example.github.io")
      end
    end

    context "CNAME to Domain to Pages" do
      let(:cname) { "www.fontawesome.it" }
      let(:domain) { "fontawesome.it" }
      let(:ip) { "185.199.108.153" }
      before(:each) do
        allow(subject).to receive(:dns) do
          [
            Dnsruby::RR.create("#{cname}. 1000 IN CNAME #{domain}"),
            a_packet
          ]
        end
      end

      it "follows the CNAMEs all the way down" do
        expect(subject.cname.host).to eq("fontawesome.it")
      end

      it "knows it's a Pages IP at the end" do
        expect(subject).to be_a_cname_to_domain_to_pages
      end
    end

    context "Random CNAME to Domain that goes to Pages" do
      let(:cname) { "monalisa" }
      let(:domain) { "fontawesome.it" }
      let(:ip) { "185.199.108.153" }
      before(:each) do
        allow(subject).to receive(:dns) do
          [
            Dnsruby::RR.create("#{cname}. 1000 IN CNAME #{domain}"),
            a_packet
          ]
        end
      end

      it "CNAME does not start with www and no match to host" do
        expect(subject).to_not be_a_cname_to_domain_to_pages
      end
    end

    context "CNAME with same host but no www" do
      let(:cname) { "blog.fontawesome.it" }
      let(:domain) { "fontawesome.it" }
      let(:ip) { "185.199.108.153" }
      before(:each) do
        allow(subject).to receive(:dns) do
          [
            Dnsruby::RR.create("#{cname}. 1000 IN CNAME #{domain}"),
            a_packet
          ]
        end
      end

      it "CNAME does not start with www and no match to host" do
        expect(subject).to_not be_a_cname_to_domain_to_pages
      end
    end

    context "CNAME starts with www but different host" do
      let(:cname) { "www.fontawesome.it" }
      let(:domain) { "awesomefont.it" }
      let(:ip) { "185.199.108.153" }
      before(:each) do
        allow(subject).to receive(:dns) do
          [
            Dnsruby::RR.create("#{cname}. 1000 IN CNAME #{domain}"),
            a_packet
          ]
        end
      end

      it "CNAME does not match to host" do
        expect(subject).to_not be_a_cname_to_domain_to_pages
      end
    end

    context "CNAME to Domain that doesn't go to Pages" do
      let(:cname) { "www.fontawesome.it" }
      let(:domain) { "fontawesome.it" }
      let(:ip) { "127.0.0.1" }
      before(:each) do
        allow(subject).to receive(:dns) do
          [
            Dnsruby::RR.create("#{cname}. 1000 IN CNAME #{domain}"),
            a_packet
          ]
        end
      end

      it "knows it's not a Pages IP at the end" do
        expect(subject).to_not be_a_cname_to_domain_to_pages
      end
    end

    context "broken CNAMEs" do
      before do
        allow(subject).to receive(:dns) do
          [Dnsruby::RR.create("#{domain}. 300 IN CNAME @.")]
        end
      end

      it "handles a broken CNAME gracefully" do
        expect(subject).to_not be_a_cname
        expect(subject.cname).to_not be_a_valid_domain
      end
    end

    it "returns the cname" do
      expect(subject.cname.host).to eql(domain)
    end

    context "with a subdomain" do
      let(:domain) { "blog.parkermoore.de" }

      it "knows a subdomain is not an apex domain" do
        expect(subject).to_not be_an_apex_domain
      end
    end

    context "with a co.uk subdomain" do
      let(:domain) { "www.bbc.co.uk" }

      it "knows a subdomain is not an apex domain" do
        expect(subject).to_not be_an_apex_domain
      end
    end

    context "apex records" do
      ["parkermoore.de", "bbc.co.uk", "techblog.netflix.com"].each do |apex_domain|
        context "given domain: #{apex_domain} with SOA" do
          before(:each) { allow(subject).to receive(:dns) { [soa_packet, ns_packet] } }

          let(:domain) { apex_domain }

          it "knows it should be an a record" do
            expect(subject.should_be_a_record?).to be_truthy
          end
        end
      end

      ["blog.parkermoore.de", "www.bbc.co.uk",
       "foo.github.io", "pages.github.com"].each do |apex_domain|
        context "given #{apex_domain}" do
          let(:domain) { apex_domain }

          it "knows it shouldn't be an a record" do
            expect(subject.should_be_a_record?).to be_falsy
          end
        end
      end

      ["private.dns.zone"].each do |soa_domain|
        context "given #{soa_domain}" do
          before(:each) { allow(subject).to receive(:dns) { [soa_packet, ns_packet] } }
          let(:domain) { soa_domain }

          it "allows child zones with an SOA to be an Apex" do
            expect(subject.should_be_a_record?).to eq(true)
          end

          it "reports whether child zones publish an SOA record" do
            expect(subject.dns_zone_soa?).to be_truthy
          end
        end
      end

      context "a domain with an MX record" do
        let(:domain) { "blog.parkermoore.de" }
        before(:each) do
          allow(subject).to receive(:dns) { [a_packet, mx_packet] }
          stub_request(:head, "http://#{domain}")
            .to_return(:status => 200, :headers => { "Server" => "GitHub.com" })
        end

        it { is_expected.to be_should_be_a_record }
        it { is_expected.to be_valid }

        context "pointed to Fastly" do
          let(:ip) { "151.101.33.147" }

          it { is_expected.to be_a_fastly_ip }
        end
      end
    end

    context "only MX records" do
      before(:each) { allow(subject).to receive(:dns) { [mx_packet] } }
      let(:domain) { "pages.invalid" }

      it "must not be valid" do
        expect(subject).not_to be_valid
      end

      it "does not think it forwards to a Fastly IP" do
        expect(subject).not_to be_a_fastly_ip
      end
    end

    context "CNAMEs to Pages" do
      before(:each) { allow(subject).to receive(:dns) { [cname_packet] } }

      ["parkr.github.io", "mattr-.github.com"].each do |cname|
        context cname do
          let(:domain) { cname }

          it "can determine a valid GitHub Pages CNAME value" do
            expect(subject).to be_a_cname_to_github_user_domain
          end
        end
      end

      ["github.com", "ben.balter.com"].each do |cname|
        context cname do
          let(:domain) { cname }

          it "can determine a valid GitHub Pages CNAME value" do
            expect(subject).to_not be_a_cname_to_github_user_domain
          end
        end
      end
    end

    context "CNAMEs" do
      let(:domain) { "foo.github.biz" }
      before(:each) { allow(subject).to receive(:dns) { [cname_packet] } }

      it "detects invalid CNAMEs" do
        expect(subject).to be_a_valid_domain
        expect(subject).to_not be_a_github_domain
        expect(subject).to_not be_an_apex_domain
        expect(subject).to_not be_a_cname_to_github_user_domain
        expect(subject).to be_an_invalid_cname
      end

      context "to pages.github.com" do
        let(:cname) { "pages.github.com" }

        it "flags CNAMEs to pages.github.com as invalid" do
          expect(subject).to be_an_invalid_cname
        end

        it "knows when the domain is CNAME'd to pages.github.com" do
          expect(subject).to be_a_cname_to_pages_dot_github_dot_com
        end
      end

      context "to fastly" do
        context "github map" do
          let(:cname) { "github.map.fastly.net" }

          it "flags CNAMEs directly to fastly as invalid" do
            expect(subject).to be_an_invalid_cname
          end

          it "knows when the domain is CNAME'd to fastly" do
            expect(subject).to be_a_cname_to_fastly
          end
        end

        context "sni.github map" do
          let(:cname) { "sni.github.map.fastly.net" }

          it "flags CNAMEs directly to fastly as invalid" do
            expect(subject).to be_an_invalid_cname
          end

          it "knows when the domain is CNAME'd to fastly" do
            expect(subject).to be_a_cname_to_fastly
          end
        end
      end

      context "to other subdomains" do
        let(:cname) { "foo.github.io" }

        it "knows CNAMEs to user subdomains are valid" do
          expect(subject.invalid_cname?).to be_falsy
        end

        it "knows when the domain is CNAME'd to a user domain" do
          expect(subject).to be_a_cname_to_github_user_domain
        end
      end
    end
  end

  context "domains" do
    context "github domains" do
      let(:domain) { "government.github.com" }

      it "knows if the domain is a github domain" do
        expect(subject).to be_a_github_domain
      end
    end

    context "fastly domain" do
      let(:domain) { "github.map.fastly.net" }

      it "knows if the domain is a fastly domain" do
        expect(subject).to be_fastly
      end
    end

    context "apex domains" do
      let(:domain) { "parkermoore.de" }

      it "knows what an apex domain is" do
        expect(subject).to be_an_apex_domain
      end
    end
  end

  context "cloudflare" do
    let(:ip) { "108.162.196.20" }
    before(:each) { allow(subject).to receive(:dns) { [a_packet] } }

    it "knows when the domain is on cloudflare" do
      expect(subject).to be_a_cloudflare_ip
    end

    context "a random IP" do
      let(:ip) { "1.1.1.1" }

      it "know's it's not cloudflare" do
        expect(subject).to_not be_a_cloudflare_ip
      end
    end
  end

  context "cloudflare IPv6" do
    let(:ip6) { "2405:b500:7000:8000:9000:A000:B000:C000" }
    before(:each) { allow(subject).to receive(:dns) { [aaaa_packet] } }

    it "knows when the domain is on cloudflare" do
      expect(subject).to be_a_cloudflare_ip
    end

    context "a random IP" do
      let(:ip6) { "2a04:4e40:1000:2000:3000:4000:5000:6000" }

      it "know's it's not cloudflare" do
        expect(subject).to_not be_a_cloudflare_ip
      end
    end
  end

  context "GitHub Pages IPs" do
    context "apex domains" do
      context "pointed to Pages IP" do
        let(:domain) { "fontawesome.io" }
        let(:ip) { "185.199.108.153" }
        before(:each) { allow(subject).to receive(:dns) { [a_packet] } }

        it "Knows it's a Pages IP" do
          expect(subject).to be_pointed_to_github_pages_ip
        end
      end

      context "not pointed to a pages IP" do
        let(:domain) { "example.com" }

        it "knows it's not a Pages IP" do
          expect(subject).to_not be_pointed_to_github_pages_ip
        end
      end
    end

    context "subdomains" do
      let(:domain) { "pages.github.com" }

      it "Knows it's not a Pages IP" do
        expect(subject).to_not be_pointed_to_github_pages_ip
      end
    end
  end

  context "GitHub Pages IPv6s" do
    context "apex domains" do
      context "pointed to Pages IPv6" do
        let(:domain) { "myipv6.io" }
        let(:ip6) { "2606:50C0:8000::153" }
        before(:each) { allow(subject).to receive(:dns) { [aaaa_packet] } }

        it "Knows it's a Pages IP" do
          expect(subject).to be_pointed_to_github_pages_ip
        end
      end

      context "not pointed to a pages IP" do
        let(:domain) { "example.com" }
        let(:ip6) { "::1" }

        it "knows it's not a Pages IP" do
          expect(subject).to_not be_pointed_to_github_pages_ip
        end
      end
    end
  end

  context "Pages domains" do
    ["pages.github.com",
     "pages.github.io",
     "pages.github.io."].each do |pages_domain|
      context pages_domain do
        let(:domain) { pages_domain }

        it "can detect pages domains" do
          expect(subject).to be_a_pages_domain
        end
      end
    end

    ["github.com", "google.co.uk"].each do |random_domain|
      context random_domain do
        let(:domain) { random_domain }

        it "doesn't detect non-pages domains as a pages domain" do
          expect(subject).to_not be_a_pages_domain
        end
      end
    end
  end

  context "no protocol switch" do
    let(:log_file) { "/tmp/bad-redirection.log" }
    before do
      File.open(log_file, "w")
    end

    it "it follows ftp if requested" do
      # Make a real request to a local server started with /script/test-redirections
      Typhoeus.get(
        "http://localhost:9988",
        GitHubPages::HealthCheck.typhoeus_options.merge(:redir_protocols => %i[http https ftp])
      )

      # Confirm port 9986 was hit (it is the FTP one)
      expect(File.read(log_file).strip).to eq("HIT 9988 HIT 9987 HIT 9986")
    end

    it "it does not follow anything other than http/https by default" do
      # Make a real request to a local server started with /script/test-redirections
      Typhoeus.get(
        "http://localhost:9988",
        GitHubPages::HealthCheck.typhoeus_options
      )

      # Confirm port 9986 was NOT hit (it is the FTP one)
      expect(File.read(log_file).strip).to eq("HIT 9988 HIT 9987")
    end
  end

  context "served by pages" do
    let(:domain) { "http://choosealicense.com" }
    let(:status) { 200 }
    let(:headers) { {} }

    before do
      allow(subject).to receive(:dns) { [a_packet] }
      stub_request(:head, domain)
        .to_return(:status => status, :headers => headers)

      stub_request(:head, "https://githubuniverse.com/")
        .to_return(:status => 200, :headers => { :server => "GitHub.com" })

      stub_request(:head, "https://github.com/login")
        .to_return(:status => 200, :headers => { :server => "GitHub.com" })
    end

    context "with the Pages server header" do
      let(:headers) { { :server => "GitHub.com" } }

      it "knows when a domain is served by pages" do
        expect(subject).to be_served_by_pages
      end

      context "with a 404" do
        let(:status) { 404 }

        it "knows when a domain is served by pages even if it returns a 404" do
          expect(subject).to be_served_by_pages
        end
      end

      context "a GitHub domain" do
        let(:domain) { "https://mac.github.com" }

        it "knows when a GitHub domain is served by pages" do
          expect(subject).to be_served_by_pages
        end
      end

      context "an alternate domain" do
        let(:domain) { "http://www.githubuniverse.com" }
        let(:status) { 301 }
        let(:headers) { { :location => "https://githubuniverse.com" } }
        before(:each) { allow(subject).to receive(:dns) { [cname_packet] } }

        it "knows about domains that redirect to the primary domain on pages" do
          expect(subject).to be_served_by_pages
        end
      end

      context "a private page" do
        let(:domain) { "http://private-page.githubapp.com" }
        let(:status) { 302 }
        let(:headers) { { :location => "https://github.com/login" } }

        it "considers it valid if it redirects to github.com/login" do
          expect(subject).to be_served_by_pages
        end
      end
    end

    context "with a request ID" do
      let(:headers) { { "X-GitHub-Request-Id" => "1234" } }

      it "falls back to the request ID" do
        expect(subject).to be_served_by_pages
      end
    end

    context "a redirect to /" do
      let(:domain) { "http://getbootstrap.com" }

      before do
        stub_request(:head, domain)
          .to_return(:status => 302, :headers => { :location => "/" })

        stub_request(:head, "#{domain}/")
          .to_return(:status => status, :headers => { :server => "GitHub.com" })
      end

      it "knows it's served by pages" do
        expect(subject).to be_served_by_pages
      end
    end

    context "an https redirect" do
      let(:domain) { "management.cio.gov" }

      before do
        stub_request(:head, "http://#{domain}")
          .to_return(:status => 302,
                     :headers => { :location => "https://#{domain}" })

        stub_request(:head, "https://#{domain}")
          .to_return(:status => status, :headers => { :server => "GitHub.com" })
      end

      it "knows when a domain with a redirect is served by pages" do
        expect(subject).to be_served_by_pages
      end
    end

    context "domains with underscores" do
      let(:domain) { "this_domain_is_valid.example.com" }
      let(:cname)  { "something.example.com" }
      let(:headers) { { :server => "GitHub.com" } }
      before(:each) { allow(subject).to receive(:dns) { [cname_packet] } }

      it "doesn't error out on domains with underscores" do
        expect(subject).to be_served_by_pages
        expect(subject).to be_valid
      end
    end

    context "private tlds in the public suffix list" do
      let(:domain) { "githubusercontent.com" }
      let(:cname)  { "something.example.com" }
      let(:headers) { { :server => "GitHub.com" } }
      before(:each) { allow(subject).to receive(:dns) { [cname_packet] } }

      it "doesn't error out on private tlds in the public suffix list" do
        expect(subject).to be_served_by_pages
        expect(subject).to be_valid
      end
    end

    context "domains with unicode encoding" do
      let(:domain) { "dómain.example.com" }
      let(:cname)  { "sómething.example.com" }
      let(:headers) { { :server => "GitHub.com" } }
      before(:each) { allow(subject).to receive(:dns) { [cname_packet] } }

      it "doesn't error out on domains with unicode encoding" do
        expect(subject).to be_served_by_pages
        expect(subject).to be_valid
      end
    end

    context "domains with punycode encoding" do
      let(:domain) { "xn--dmain-0ta.example.com" }
      let(:cname)  { "xn--smething-v3a.example.com" }
      let(:headers) { { :server => "GitHub.com" } }
      before(:each) { allow(subject).to receive(:dns) { [cname_packet] } }

      it "doesn't error out on domains with punycode encoding" do
        expect(subject).to be_served_by_pages
        expect(subject).to be_valid
      end
    end
  end

  context "not served by pages" do
    let(:domain) { "http://choosealicense.com" }
    let(:status) { 200 }
    let(:headers) { {} }
    let(:not_served_error) do
      GitHubPages::HealthCheck::Errors::NotServedByPagesError
    end

    before do
      stub_request(:head, domain)
        .to_return(:status => status, :headers => headers)
    end

    context "a random domain" do
      let(:domain) { "geogle.com" }
      let(:ip) { "127.0.0.1" }
      before(:each) { allow(subject).to receive(:dns) { [a_packet] } }

      it "knows when a domain isn't served by pages" do
        expect(subject).to_not be_served_by_pages
        expect(subject.reason).to be_a(not_served_error)
        msg = "Domain does not resolve to the GitHub Pages server"
        expect(subject.reason.message).to eql(msg)
      end
    end

    context "a non-CNAME" do
      let(:domain) { "techblog.netflix.com" }
      let(:cname_error) do
        GitHubPages::HealthCheck::Errors::InvalidCNAMEError
      end
      let(:cname) { "netflix.com" }
      before(:each) { allow(subject).to receive(:dns) { [cname_packet] } }

      it "returns the error" do
        expect(subject.valid?).to be_falsy
        expect(subject.mx_records_present?).to be_falsy
        expect(subject.should_be_cname_record?).to be_truthy
        expect(subject.reason).to be_a(cname_error)
        regex = /not set up with a correct CNAME record/i
        expect(subject.reason.message).to match(regex)
      end
    end
  end

  context "proxies" do
    context "by IP" do
      before(:each) { allow(subject).to receive(:dns) { [a_packet] } }

      context "cloudflare" do
        let(:ip) { "108.162.196.20" }

        it "knows cloudflare sites are proxied" do
          expect(subject).to be_proxied
        end
      end

      context "a pages IP" do
        let(:ip) { "185.199.108.153" }

        it "knows a site pointed to a Pages IP isn't proxied" do
          expect(subject).to_not be_proxied
        end
      end
    end

    context "by cname" do
      before(:each) { allow(subject).to receive(:dns) { [cname_packet] } }

      context "pointed to pages" do
        let(:cname) { "foo.github.io" }

        it "knows a site pointed to a Pages domain isn't proxied" do
          expect(subject).to_not be_proxied
        end
      end

      context "pointed to pages.github.com" do
        let(:cname) { "pages.github.com" }

        it "knows a site CNAMEd to pages.github.com isn't proxied" do
          expect(subject).to_not be_proxied
        end
      end

      context "pointed to Fastly" do
        let(:cname) { "github.map.fastly.net" }
        let(:domain) { "foo.github.biz" }

        before do
          stub_request(:head, "http://#{domain}")
            .to_return(:status => 200, :headers => { :server => "GitHub.com" })
        end

        it "knows a site CNAME'd directly to Fastly isn't proxied" do
          expect(subject).to_not be_proxied
        end
      end
    end

    context "proxying" do
      let(:headers) { { :server => "GitHub.com" } }
      let(:status) { 200 }
      before(:each) do
        stub_request(:head, domain)
          .to_return(:status => status, :headers => headers)
        allow(subject).to receive(:dns) { [a_packet] }
      end

      context "a site that returns GitHub.com headers" do
        let(:domain) { "http://management.cio.gov" }

        it "detects proxied sites" do
          expect(subject).to be_proxied
        end
      end

      context "a random site" do
        let(:domain) { "http://google.com" }
        let(:headers) { {} }

        it "knows a site not served by pages isn't proxied" do
          expect(subject).to_not be_proxied
        end
      end
    end
  end

  context "github domains" do
    context "pages.github.com" do
      let(:domain) { "pages.github.com" }

      it "knows when the domain is a github domain" do
        expect(subject).to be_a_github_domain
      end
    end

    context "choosealicense.com" do
      let(:domain) { "choosealicense.com" }

      it "knows when the domain is not a github domain" do
        expect(subject).to_not be_a_github_domain
      end
    end

    context "benbalter.github.io" do
      let(:domain) { "benbalter.github.io" }

      it "knows when the domain is not a github domain" do
        expect(subject).to_not be_a_github_domain
      end
    end
  end

  context "invalid domains" do
    let(:domain) { "this-domain-does-not-exist-and-should-not-ever-exist.io" }

    it "does not resolve domains that do not exist" do
      expect(subject.dns).to be_nil
    end

    context "a valid domain" do
      let(:domain) { "github.com" }

      it "is valid" do
        expect(subject).to be_a_valid_domain
      end
    end

    context "an invalid domain" do
      let(:domain) { "github.invalid" }

      it "is invalid" do
        expect(subject).to_not be_a_valid_domain
        error = GitHubPages::HealthCheck::Errors::InvalidDomainError
        expect(subject.reason).to be_a(error)
        expect(subject.reason.message).to eql("Domain is not a valid domain")
      end
    end
  end

  it "returns the Typhoeus options" do
    expected = Regexp.escape GitHubPages::HealthCheck::VERSION
    header = GitHubPages::HealthCheck.typhoeus_options[:headers]["User-Agent"]
    expect(header).to match(expected)
  end

  context "dns" do
    let(:domain) { "pages.github.com" }

    it "retrieves a site's dns record" do
      expect(subject).to be_dns_resolves
      expect(subject.dns.first).to be_a(Dnsruby::RR::CNAME)
    end

    context "with DNS stubbed" do
      let(:ip) { "1.2.3.4" }
      before(:each) { allow(subject).to receive(:dns) { [a_packet] } }

      it "knows when the DNS resolves" do
        expect(subject.dns?).to be_truthy
      end
    end

    context "when DNS doesn't resolve" do
      before(:each) { allow(subject).to receive(:dns) { nil } }

      it "knows when the DNS doesn't resolve" do
        expect(subject.dns?).to be_falsy
      end

      it "treats cname as nil if DNS doesn't resolve" do
        expect(subject.cname).to be_nil
      end
    end

    context "an invalid domain" do
      let(:domain) { "example.invalid" }

      it "knows when a domain has no record" do
        expect(subject.dns?).to be_falsy
      end
    end
  end

  context "https" do
    let(:domain) { "pages.github.com" }
    let(:return_code) { nil }

    before do
      stub_request(:head, "https://#{domain}/")
        .to_return(:status => 200, :headers => { :server => "GitHub.com" })
      allow(subject.send(:https_response)).to receive(:return_code) { return_code }
    end

    context "a site that supports HTTPS" do
      let(:return_code) { :ok }

      it "knows it supports https" do
        expect(subject.https?).to be_truthy
      end

      it "knows there's no error" do
        expect(subject.https_error).to be_nil
      end
    end

    context "a site that doesn't support HTTPS" do
      let(:return_code) { :ssl_cacert }

      it "knows it doesn't support https" do
        expect(subject.https?).to be_falsy
      end

      it "knows the error reason" do
        expect(subject.https_error).to eql(:ssl_cacert)
      end

      it "knows it doesn't enforce https" do
        expect(subject.enforces_https?).to be_falsy
      end
    end

    context "a site that enforces HTTPS" do
      let(:return_code) { :ok }
      before do
        stub_request(:head, "http://#{domain}/")
          .to_return(:status => 301,
                     :headers => { :Location => "https://#{domain}" })
      end

      it "knows it supports https" do
        expect(subject.https?).to be_truthy
      end

      it "knows it enforces https" do
        expect(subject.enforces_https?).to be_truthy
      end
    end

    context "a site with a relative redirect" do
      let(:return_code) { :ok }
      before do
        stub_request(:head, "http://#{domain}/")
          .to_return(:status => 301, :headers => { :Location => "/versions" })
      end

      it "knows it doesn't enforce https" do
        expect(subject.enforces_https?).to be_falsy
      end
    end
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

      context "with underscore domain" do
        let(:domain) { "foo_bar.com" }

        it { is_expected.not_to be_https_eligible }
      end

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

    context "AAAA records pointed to current IPs" do
      let(:ip6) { "2606:50C0:8002::153" }
      before(:each) { allow(subject).to receive(:dns) { [aaaa_packet] } }
      before(:each) { allow(subject.send(:caa)).to receive(:query) { [aaaa_packet] } }

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
        let(:ip6) { "2606:50c0:8003::153" }

        it { is_expected.to be_https_eligible }
      end

      context "with bad additional A record" do
        let(:ip6) { "2606:50c0:8003::1111" }

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
    end

    context "CNAME record pointed to username" do
      let(:cname) { "foobar.github.io" }
      before(:each) { allow(subject).to receive(:dns) { [cname_packet] } }
      before(:each) { allow(subject.send(:caa)).to receive(:query) { [cname_packet] } }

      it { is_expected.to be_https_eligible }

      context "with bad CAA records" do
        let(:caa_domain) { "digicert.com" }
        before(:each) { allow(subject.send(:caa)).to receive(:query) { [caa_packet] } }

        it { is_expected.to be_https_eligible }
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

          it { is_expected.to be_https_eligible }
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

          it { is_expected.to be_https_eligible }
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
