require "spec_helper"

describe(GitHubPages::HealthCheck::Domain) do
  def make_domain_check(domain="foo.github.io")
    GitHubPages::HealthCheck::Domain.new(domain)
  end

  def a_packet(ip)
    Net::DNS::RR::A.new(:name => "pages.invalid", :address => ip, :ttl => 1000)
  end

  def cname_packet(domain)
    Net::DNS::RR::CNAME.new(:name => "pages.invalid", :cname => domain, :ttl => 1000)
  end

  def mx_packet
    Net::DNS::RR::MX.new(:name => "pages.invalid", :exchange => "mail.example.com", :preference => 10, :ttl => 100)
  end

  context "constructor" do
    let(:expected) { "foo.github.io" }

    it "can handle bare domains" do
      expect(make_domain_check("foo.github.io").host).to eql(expected)
    end

    it "can handle URI's" do
      expect(make_domain_check("https://foo.github.io").host).to eql(expected)
      expect(make_domain_check("http://foo.github.io").host).to eql(expected)
      expect(make_domain_check("ftp://foo.github.io").host).to eql(expected)
    end

    it "can handle paths" do
      expect(make_domain_check("foo.github.io/im-a-path/").host).to eql(expected)
      expect(make_domain_check("foo.github.io/im-a-path").host).to eql(expected)
      expect(make_domain_check("foo.github.io/index.html").host).to eql(expected)
    end

    it "strips whitespace" do
      expect(make_domain_check(" foo.github.io ").host).to eql(expected)
    end

    it "normalizes FQDNs" do
      expect(make_domain_check("foo.github.io.").host).to eql(expected)
    end

    it "doesn't err on invalid domains" do
      check = make_domain_check("http://@")
      expect(check.host).to eql(nil)
      expect(check.reason.class).to eql(GitHubPages::HealthCheck::Errors::InvalidDomainError)

      check = make_domain_check("//")
      expect(check.host).to eql(nil)
      expect(check.reason.class).to eql(GitHubPages::HealthCheck::Errors::InvalidDomainError)
    end
  end

  context "A records" do

    it "knows old IP addresses" do
      %w[204.232.175.78 207.97.227.245].each do |ip_address|
        domain_check = make_domain_check
        allow(domain_check).to receive(:dns) { [a_packet(ip_address)] }
        expect(domain_check.old_ip_address?).to be(true)
        expect(domain_check.deprecated_ip?).to be(true)
      end

      domain_check = make_domain_check
      allow(domain_check).to receive(:dns) { [a_packet("1.2.3.4")] }
      expect(domain_check.old_ip_address?).to be(false)
    end

    it "knows when a domain is an A record" do
      domain_check = make_domain_check
      allow(domain_check).to receive(:dns) { [a_packet("1.2.3.4")] }
      expect(domain_check.a_record?).to be(true)
      expect(domain_check.cname_record?).to be(false)
    end

    it "knows when a domain has an invalid A record" do
      domain_check = make_domain_check("foo.github.io")
      allow(domain_check).to receive(:dns) { [a_packet("1.2.3.4")] }
      expect(domain_check.a_record?).to be(true)
      expect(domain_check.valid_domain?).to be(true)
      expect(domain_check.should_be_a_record?).to be(false)
      expect(domain_check.invalid_a_record?).to be(true)
    end
  end

  context "CNAMEs" do
    it "known when a domain is a CNAME record" do
      domain_check = make_domain_check
      allow(domain_check).to receive(:dns) { [cname_packet("pages.github.com")] }
      expect(domain_check.cname_record?).to be(true)
      expect(domain_check.a_record?).to be(false)
    end

    it "handles a broken CNAME gracefully" do
      domain_check = make_domain_check
      allow(domain_check).to receive(:dns) do
        [cname_packet("example.com").tap {|c| c.instance_variable_set(:@cname, "@.") }]
      end
      expect(domain_check.cname?).to be(false)
      expect(domain_check.cname.valid_domain?).to be(false)
    end

    it "returns the cname" do
      domain_check = make_domain_check
      allow(domain_check).to receive(:dns) { [cname_packet("pages.github.com")] }
      expect(domain_check.cname.host).to eql("pages.github.com")
    end

    it "knows a subdomain is not an apex domain" do
      domain_check = make_domain_check "blog.parkermoore.de"
      expect(domain_check.apex_domain?).to be(false)

      domain_check = make_domain_check "www.bbc.co.uk"
      expect(domain_check.apex_domain?).to be(false)
    end

    it "knows what should be an apex record" do
      domain_check = make_domain_check("parkermoore.de")
      expect(domain_check.should_be_a_record?).to be(true)

      domain_check = make_domain_check("bbc.co.uk")
      expect(domain_check.should_be_a_record?).to be(true)

      domain_check = make_domain_check("blog.parkermoore.de")
      expect(domain_check.should_be_a_record?).to be(false)

      domain_check = make_domain_check("www.bbc.co.uk")
      expect(domain_check.should_be_a_record?).to be(false)

      domain_check = make_domain_check("foo.github.io")
      expect(domain_check.should_be_a_record?).to be(false)

      domain_check = make_domain_check("pages.github.com")
      expect(domain_check.should_be_a_record?).to be(false)

      domain_check = make_domain_check("blog.parkermoore.de")
      allow(domain_check).to receive(:dns) { [a_packet("1.2.3.4"), mx_packet] }
      expect(domain_check.should_be_a_record?).to be(true)
    end

    it "can determine a valid GitHub Pages CNAME value" do
      ["parkr.github.io", "mattr-.github.com"].each do |domain|
        domain_check = make_domain_check
        allow(domain_check).to receive(:dns) { [cname_packet(domain)] }
        expect(domain_check.cname_to_github_user_domain?).to be(true)
      end
      ["github.com", "ben.balter.com"].each do |domain|
        domain_check = make_domain_check
        allow(domain_check).to receive(:dns) { [cname_packet(domain)] }
        expect(domain_check.cname_to_github_user_domain?).to be(false)
      end
    end

    it "detects invalid CNAMEs" do
      domain_check = make_domain_check("foo.github.biz")
      allow(domain_check).to receive(:dns) { [cname_packet("foo.github.biz")] }
      expect(domain_check.valid_domain?).to be(true)
      expect(domain_check.github_domain?).to be(false)
      expect(domain_check.apex_domain?).to be(false)
      expect(domain_check.cname_to_github_user_domain?).to eql(false)
      expect(domain_check.invalid_cname?).to eql(true)
    end

    it "flags CNAMEs to pages.github.com as invalid" do
      domain_check = make_domain_check("foo.github.biz")
      allow(domain_check).to receive(:dns) { [cname_packet("pages.github.com")] }
      expect(domain_check.invalid_cname?).to eql(true)
    end

    it "flags CNAMEs directly to fastly as invalid" do
      domain_check = make_domain_check("foo.github.biz")
      allow(domain_check).to receive(:dns) { [cname_packet("github.map.fastly.net")] }
      expect(domain_check.invalid_cname?).to eql(true)
    end

    it "knows CNAMEs to user subdomains are valid" do
      domain_check = make_domain_check("foo.github.biz")
      allow(domain_check).to receive(:dns) { [cname_packet("foo.github.io")] }
      expect(domain_check.invalid_cname?).to eql(false)
    end

    it "knows when the domain is CNAME'd to a user domain" do
      domain_check = make_domain_check("foo.github.biz")
      allow(domain_check).to receive(:dns) { [cname_packet("foo.github.io")] }
      expect(domain_check.cname_to_github_user_domain?).to eql(true)
    end

    it "knows when the domain is CNAME'd to pages.github.com" do
      domain_check = make_domain_check("foo.github.biz")
      allow(domain_check).to receive(:dns) { [cname_packet("pages.github.com")] }
      expect(domain_check.cname_to_pages_dot_github_dot_com?).to eql(true)
    end

    it "knows when the domain is CNAME'd to pages.github.io" do
      domain_check = make_domain_check("foo.github.biz")
      allow(domain_check).to receive(:dns) { [cname_packet("pages.github.io")] }
      expect(domain_check.cname_to_pages_dot_github_dot_com?).to eql(true)
    end

    it "knows when the domain is CNAME'd to fastly" do
      domain_check = make_domain_check("foo.github.biz")
      allow(domain_check).to receive(:dns) { [cname_packet("github.map.fastly.net")] }
      expect(domain_check.cname_to_fastly?).to eql(true)
    end
  end

  it "knows if the domain is a github domain" do
    domain_check = make_domain_check("government.github.com")
    expect(domain_check.github_domain?).to eql(true)
  end

  it "knows if the domain is a fastly domain" do
    domain_check = make_domain_check("github.map.fastly.net")
    expect(domain_check.fastly?).to eql(true)
  end

  context "apex domains" do
    it "knows what an apex domain is" do
      domain_check = make_domain_check "parkermoore.de"
      expect(domain_check.apex_domain?).to be(true)

      domain_check = make_domain_check "bbc.co.uk"
      expect(domain_check.apex_domain?).to be(true)
    end
  end

  context "cloudflare" do
    it "knows when the domain is on cloudflare" do
      domain_check = make_domain_check
      allow(domain_check).to receive(:dns) { [a_packet("108.162.196.20")] }
      expect(domain_check.cloudflare_ip?).to be(true)

      domain_check = make_domain_check
      allow(domain_check).to receive(:dns) { [a_packet("1.1.1.1")] }
      expect(domain_check.cloudflare_ip?).to be(false)
    end
  end

  context "GitHub Pages IPs" do
    it "can determine when an apex domain is pointed at a GitHub Pages IP address" do
      domain_check = make_domain_check "fontawesome.io"
      expect(domain_check.pointed_to_github_pages_ip?).to be(true)
    end

    it "can determine when an apex domain is not pointed at a GitHub Pages IP address" do
      domain_check = make_domain_check "example.com"
      expect(domain_check.pointed_to_github_pages_ip?).to be(false)
    end

    it "can determine that a subdomain with a CNAME record is not pointed at a GitHub Pages IP address" do
      domain_check = make_domain_check "pages.github.com"
      expect(domain_check.pointed_to_github_pages_ip?).to be(false)
    end
  end

  context "Pages domains" do
    it "can detect pages domains" do
      domain_check = make_domain_check "pages.github.com"
      expect(domain_check.pages_domain?).to be(true)

      domain_check = make_domain_check "pages.github.io"
      expect(domain_check.pages_domain?).to be(true)

      domain_check = make_domain_check "pages.github.io."
      expect(domain_check.pages_domain?).to be(true)
    end

    it "doesn't detect non-pages domains as a pages domain" do
      domain_check = make_domain_check "github.com"
      expect(domain_check.pages_domain?).to be(false)

      domain_check = make_domain_check "google.co.uk"
      expect(domain_check.pages_domain?).to be(false)
    end
  end

  context "served by pages" do
    it "knows when a domain is served by pages" do
      stub_request(:head, "http://choosealicense.com").
         to_return(:status => 200, :headers => {:server => "GitHub.com"})

      check = make_domain_check "choosealicense.com"
      expect(check.served_by_pages?).to eql(true)
    end

    it "falls back to the request ID" do
      stub_request(:head, "http://choosealicense.com").
         to_return(:status => 200, :headers => {"X-GitHub-Request-Id" => "1234"})

      check = make_domain_check "choosealicense.com"
      expect(check.served_by_pages?).to eql(true)
    end

    it "knows when a domain is served by pages even if it returns a 404" do
      stub_request(:head, "http://foo.github.io").
         to_return(:status => 404, :headers => {:server => "GitHub.com"})

      check = make_domain_check "foo.github.io"
      expect(check.served_by_pages?).to eql(true)
    end

    it "knows when a GitHub domain is served by pages" do
      stub_request(:head, "https://mac.github.com").
         to_return(:status => 200, :headers => {:server => "GitHub.com"})

      check = make_domain_check "mac.github.com"
      expect(check.served_by_pages?).to eql(true)
    end

    it "knows when an apex domain using A records is served by pages" do
      # Tests this redirect scenario for apex domains using A records:
      # › curl -I http://getbootstrap.com/
      # HTTP/1.1 302 Found
      # Location: /
      stub_request(:head, "http://getbootstrap.com").
         to_return(:status => 302, :headers => {:location => "/"})

      stub_request(:head, "http://getbootstrap.com/").
        to_return(:status => 200, :headers => {:server => "GitHub.com"})

      check = make_domain_check "getbootstrap.com"
      expect(check.served_by_pages?).to eql(true)
    end

    it "knows when a domain with a redirect is served by pages" do
      stub_request(:head, "http://management.cio.gov").
         to_return(:status => 302, :headers => {:location => "https://management.cio.gov"})

      stub_request(:head, "https://management.cio.gov").
       to_return(:status => 200, :headers => {:server => "GitHub.com"})

      check = make_domain_check "management.cio.gov"
      expect(check.served_by_pages?).to eql(true)
    end

    # https://stackoverflow.com/questions/5208851/is-there-a-workaround-to-open-urls-containing-underscores-in-ruby
    it "doesn't error out on domains with underscores" do
      check = make_domain_check "this_domain_is_valid.github.io"

      stub_request(:head, "this_domain_is_valid.github.io").
         to_return(:status => 200, :headers => {:server => "GitHub.com"})

      expect(check.served_by_pages?).to eql(true)
      expect(check.valid?).to eql(true)
    end
  end

  context "not served by pages" do
    it "knows when a domain isn't served by pages" do
      stub_request(:head, "http://google.com").to_return(:status => 200, :headers => {})
      check = make_domain_check "google.com"
      expect(check.served_by_pages?).to eql(false)
      expect(check.reason.class).to eql(GitHubPages::HealthCheck::Errors::NotServedByPagesError)
      expect(check.reason.message).to eql("Domain does not resolve to the GitHub Pages server")
    end

    it "returns the error" do
      stub_request(:head, "http://techblog.netflix.com").to_return(:status => 200, :headers => {})
      check = make_domain_check "techblog.netflix.com"
      expect(check.valid?).to eql(false)
      expect(check.mx_records_present?).to eq(false)
      expect(check.reason.class).to eql(GitHubPages::HealthCheck::Errors::InvalidCNAMEError)
      expect(check.reason.message).to match(/not set up with a correct CNAME record/i)
    end
  end

  context "proxies" do
    it "knows cloudflare sites are proxied" do
      domain_check = make_domain_check
      allow(domain_check).to receive(:dns) { [a_packet("108.162.196.20")] }
      expect(domain_check.proxied?).to be(true)
    end

    it "knows a site pointed to a Pages IP isn't proxied" do
      domain_check = make_domain_check
      allow(domain_check).to receive(:dns) { [a_packet("192.30.252.153")] }
      expect(domain_check.proxied?).to be(false)
    end

    it "knows a site pointed to a Pages domain isn't proxied" do
      domain_check = make_domain_check
      allow(domain_check).to receive(:dns) { [cname_packet("foo.github.io")] }
      expect(domain_check.proxied?).to be(false)
    end

    it "knows a site CNAMEd to pages.github.com isn't proxied" do
      domain_check = make_domain_check
      allow(domain_check).to receive(:dns) { [cname_packet("pages.github.com")] }
      expect(domain_check.proxied?).to be(false)
    end

    it "knows a site CNAME'd directly to Fastly isn't proxied" do
      domain_check = make_domain_check('foo.github.biz')
      allow(domain_check).to receive(:dns) { [cname_packet("github.map.fastly.net")] }
      expect(domain_check.proxied?).to be(false)
    end

    it "detects proxied sites" do
      stub_request(:head, "http://management.cio.gov").
       to_return(:status => 200, :headers => {:server => "GitHub.com"})

      check = make_domain_check "management.cio.gov"
      expect(check.proxied?).to eql(true)
    end

    it "knows a site not served by pages isn't proxied" do
      stub_request(:head, "http://google.com").to_return(:status => 200, :headers => {})
      check = make_domain_check "google.com"
      expect(check.proxied?).to eql(false)
    end
  end

  it "knows when the domain is a github domain" do
    check = make_domain_check "pages.github.com"
    expect(check.github_domain?).to eql(true)

    check = make_domain_check "choosealicense.com"
    expect(check.github_domain?).to eql(false)

    check = make_domain_check "benbalter.github.io"
    expect(check.github_domain?).to eql(false)
  end

  context "invalid domains" do
    it "does not resolve domains that do not exist" do
      check = make_domain_check "this-domain-does-not-exist-and-should-not-ever-exist.io."
      expect(check.dns).to be_empty

      check = make_domain_check "this-domain-does-not-exist-and-should-not-ever-exist.io"
      expect(check.dns).to be_empty
    end

    it "detects invalid domains" do
      domain_check = make_domain_check "github.com"
      expect(domain_check.valid_domain?).to be(true)

      domain_check = make_domain_check "github.invalid"
      expect(domain_check.valid_domain?).to be(false)

      expect(domain_check.reason.class).to eql(GitHubPages::HealthCheck::Errors::InvalidDomainError)
      expect(domain_check.reason.message).to eql("Domain is not a valid domain")
    end
  end

  it "returns the Typhoeus options" do
    expected = Regexp.escape GitHubPages::HealthCheck::VERSION
    expect(GitHubPages::HealthCheck::TYPHOEUS_OPTIONS[:headers]["User-Agent"]).to match(expected)
  end

  context "dns" do
    it "retrieves a site's dns record" do
      domain_check = make_domain_check "pages.github.com"
      expect(domain_check.dns.first.class).to eql(Net::DNS::RR::CNAME)
    end

    it "knows when the DNS resolves" do
      domain_check = make_domain_check
      allow(domain_check).to receive(:dns) { [a_packet("1.2.3.4")] }
      expect(domain_check.dns?).to be(true)
    end

    it "knows when the DNS doesn't resolve" do
      domain_check = make_domain_check
      allow(domain_check).to receive(:dns) { nil }
      expect(domain_check.dns?).to be(false)
    end

    it "knows when a domain has no record" do
      domain_check = make_domain_check "example.invalid"
      expect(domain_check.dns?).to be(false)
    end
  end

  context "https" do
    let(:domain) { "pages.github.com" }
    let(:domain_check) { make_domain_check(domain) }

    context "a site that supports HTTPS" do
      let(:domain) { "pages.github.com" }

      before do
        stub_request(:head, "https://pages.github.com/").
           to_return(:status => 200, :headers => {:server => "GitHub.com"})
         allow(domain_check.send(:https_response)).to receive(:return_code) { :ok }

      end

      it "knows it supports https" do
        expect(domain_check.https?).to eql(true)
      end

      it "knows there's no error" do
        expect(domain_check.https_error).to be_nil
      end
    end

    context "a site that doesn't support HTTPS" do
      let(:domain) { "pages.github.com" }

      before do
        stub_request(:head, "https://pages.github.com/").
           to_return(:status => 200, :headers => {:server => "GitHub.com"})
         allow(domain_check.send(:https_response)).to receive(:return_code) { :ssl_cacert }

      end

      it "knows it doesn't support https" do
        expect(domain_check.https?).to eql(false)
      end

      it "knows the error reason" do
        expect(domain_check.https_error).to eql(:ssl_cacert)
      end

      it "knows it doesn't enforce https" do
        expect(domain_check.enforces_https?).to eql(false)
      end
    end

    context "a site that enforces HTTPS" do
      let(:domain) { "pages.github.com" }

      before do
        stub_request(:head, "https://pages.github.com/").
           to_return(:status => 200, :headers => {:server => "GitHub.com"})
         allow(domain_check.send(:https_response)).to receive(:return_code) { :ok }

         stub_request(:head, "http://pages.github.com/").
            to_return(:status => 301, :headers => {:Location => "https://pages.github.com"})
      end

      it "knows it supports https" do
        expect(domain_check.https?).to eql(true)
      end

      it "knows it enforces https" do
        expect(domain_check.enforces_https?).to eql(true)
      end
    end

    context "a site with a relative redirect" do
      let(:domain) { "pages.github.com" }

      before do
        stub_request(:head, "https://pages.github.com/").
           to_return(:status => 200, :headers => {:server => "GitHub.com"})
         allow(domain_check.send(:https_response)).to receive(:return_code) { :ok }

         stub_request(:head, "http://pages.github.com/").
            to_return(:status => 301, :headers => {:Location => "/versions"})
      end

      it "knows it doesn't enforce https" do
        expect(domain_check.enforces_https?).to eql(false)
      end
    end
  end
end
