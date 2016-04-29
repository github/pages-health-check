module GitHubPages
  module HealthCheck
    class Domain < Checkable

      attr_reader :host

      LEGACY_IP_ADDRESSES = %w[
        207.97.227.245
        204.232.175.78
        199.27.73.133
      ].freeze

      CURRENT_IP_ADDRESSES = %w[
        192.30.252.153
        192.30.252.154
      ].freeze

      HASH_METHODS = [
        :host, :uri, :dns_resolves?, :proxied?, :cloudflare_ip?,
        :old_ip_address?, :a_record?, :cname_record?, :valid_domain?,
        :apex_domain?, :should_be_a_record?, :cname_to_github_user_domain?,
        :cname_to_pages_dot_github_dot_com?, :cname_to_fastly?,
        :pointed_to_github_pages_ip?, :pages_domain?, :served_by_pages?,
        :valid_domain?
      ].freeze

      def initialize(host)
        unless host.is_a? String
          raise ArgumentError, "Expected string, got #{host.class}"
        end

        @host = normalize_host(host)
      end

      # Runs all checks, raises an error if invalid
      def check!
        raise Errors::InvalidDomainError.new(domain: self) unless valid_domain?
        raise Errors::InvalidDNSError.new(domain: self)    unless dns_resolves?
        return true if proxied?
        raise Errors::DeprecatedIPError.new(domain: self)      if deprecated_ip?
        raise Errors::InvalidARecordError.new(domain: self)    if invalid_a_record?
        raise Errors::InvalidCNAMEError.new(domain: self)      if invalid_cname?
        raise Errors::NotServedByPagesError.new(domain: self)  unless served_by_pages?
        true
      end

      def deprecated_ip?
        return @deprecated_ip if defined? @deprecated_ip
        @deprecated_ip = (valid_domain? && a_record? && old_ip_address?)
      end

      def invalid_a_record?
        return @invalid_a_record if defined? @invalid_a_record
        @invalid_a_record = (valid_domain? && a_record? && !should_be_a_record?)
      end

      def invalid_cname?
        return @invalid_cname if defined? @invalid_cname
        @invalid_cname = begin
          return false unless valid_domain?
          return false if github_domain? || apex_domain?
          return true  if cname_to_pages_dot_github_dot_com? || cname_to_fastly?
          !cname_to_github_user_domain?
        end
      end

      # Is this a valid domain that PublicSuffix recognizes?
      # Used as an escape hatch to prevent false positives on DNS checkes
      def valid_domain?
        return @valid if defined? @valid
        @valid = PublicSuffix.valid?(host)
      end

      # Is this domain an apex domain, meaning a CNAME would be innapropriate
      def apex_domain?
        return @apex_domain if defined?(@apex_domain)
        return unless valid_domain?

          answers = begin
            Resolv::DNS.open { |dns|
              dns.timeouts = TIMEOUT
              dns.getresources(absolute_domain, Resolv::DNS::Resource::IN::NS)
            }
          rescue Timeout::Error, NoMethodError
            []
          end

        @apex_domain = answers.any?
      end

      # Should the domain be an apex record?
      def should_be_a_record?
        !pages_domain? && apex_domain?
      end

      # Is the domain's first response an A record to a valid GitHub Pages IP?
      def pointed_to_github_pages_ip?
        a_record? && CURRENT_IP_ADDRESSES.include?(dns.first.value)
      end

      # Is the domain's first response a CNAME to a pages domain?
      def cname_to_github_user_domain?
        cname? && !cname_to_pages_dot_github_dot_com? && cname.pages_domain?
      end

      # Is the given domain a CNAME to pages.github.(io|com)
      # instead of being CNAME'd to the user's subdomain?
      #
      # domain - the domain to check, generaly the target of a cname
      def cname_to_pages_dot_github_dot_com?
        cname? && cname.pages_dot_github_dot_com?
      end

      # Is the given domain CNAME'd directly to our Fastly account?
      def cname_to_fastly?
        cname? && !pages_domain? && cname.fastly?
      end

      # Is the host a *.github.io domain?
      def pages_domain?
        !!host.match(/\A[\w-]+\.github\.(io|com)\.?\z/i)
      end

      # Is the host pages.github.com or pages.github.io?
      def pages_dot_github_dot_com?
        !!host.match(/\Apages\.github\.(io|com)\.?\z/i)
      end

      # Is this domain owned by GitHub?
      def github_domain?
        !!host.match(/\.github\.com\z/)
      end

      # Is the host our Fastly CNAME?
      def fastly?
        !!host.match(/\Agithub\.map\.fastly\.net\.?\z/i)
      end

      # Does the domain resolve to a CloudFlare-owned IP
      def cloudflare_ip?
        return unless dns?
        dns.all? do |answer|
          answer.class == Net::DNS::RR::A && CloudFlare.controls_ip?(answer.address)
        end
      end

      # Does this non-GitHub-pages domain proxy a GitHub Pages site?
      #
      # This can be:
      #   1. A Cloudflare-owned IP address
      #   2. A site that returns GitHub.com server headers, but isn't CNAME'd to a GitHub domain
      #   3. A site that returns GitHub.com server headers, but isn't CNAME'd to a GitHub IP
      def proxied?
        return unless dns?
        return true if cloudflare_ip?
        return false if pointed_to_github_pages_ip? || cname_to_github_user_domain?
        return false if cname_to_pages_dot_github_dot_com? || cname_to_fastly?
        served_by_pages?
      end

      # Returns an array of DNS answers
      def dns
        return @dns if defined? @dns
        return unless valid_domain?
        @dns = Timeout.timeout(TIMEOUT) do
          GitHubPages::HealthCheck.without_warnings do
            Net::DNS::Resolver.start(absolute_domain).answer unless host.nil?
          end
        end
      rescue StandardError
        @dns = nil
      end

      # Are we even able to get the DNS record?
      def dns?
        !(dns.nil? || dns.empty?)
      end
      alias_method :dns_resolves?, :dns?

      # Does this domain have *any* A record that points to the legacy IPs?
      def old_ip_address?
        dns.any? do |answer|
          answer.class == Net::DNS::RR::A && LEGACY_IP_ADDRESSES.include?(answer.address.to_s)
        end if dns?
      end

      # Is this domain's first response an A record?
      def a_record?
        return unless dns?
        dns.first.class == Net::DNS::RR::A
      end

      # Is this domain's first response a CNAME record?
      def cname_record?
        return unless dns?
        dns.first.class == Net::DNS::RR::CNAME
      end
      alias cname? cname_record?

      # The domain to which this domain's CNAME resolves
      # Returns nil if the domain is not a CNAME
      def cname
        return unless cname?
        @cname ||= Domain.new(dns.first.cname.to_s)
      end

      def served_by_pages?
        return @served_by_pages if defined? @served_by_pages
        return unless dns_resolves?

        @served_by_pages = begin
          response = Typhoeus.head(uri, TYPHOEUS_OPTIONS)

          # Workaround for webmock not playing nicely with Typhoeus redirects
          # See https://github.com/bblimke/webmock/issues/237
          if response.mock? && response.headers["Location"]
            response = Typhoeus.head(response.headers["Location"], TYPHOEUS_OPTIONS)
          end

          return false unless response.mock? || response.return_code == :ok
          return true if response.headers["Server"] == "GitHub.com"

          # Typhoeus mangles the case of the header, compare insensitively
          response.headers.any? { |k,v| k =~ /X-GitHub-Request-Id/i }
        end
      end

      def uri
        @uri ||= begin
          options = { :host => host, :scheme => scheme, :path => "/" }
          Addressable::URI.new(options).normalize.to_s
        end
      end

      private

      # Parse the URI. Accept either domain names or full URI's.
      # Used by the initializer so we can be more flexible with inputs.
      #
      # domain - a URI or domain name.
      #
      # Examples
      #
      #   normalize_host("benbalter.github.com")
      #   # => 'benbalter.github.com'
      #   normalize_host("https://benbalter.github.com")
      #   # => 'benbalter.github.com'
      #   normalize_host("benbalter.github.com/help-me-im-a-path/")
      #   # => 'benbalter.github.com'
      #
      # Return the hostname.
      def normalize_host(domain)
        domain = domain.strip.chomp(".")
        host = Addressable::URI.parse(domain).host || Addressable::URI.parse("http://#{domain}").host
        host unless host.to_s.empty?
      rescue Addressable::URI::InvalidURIError
        nil
      end

      # Adjust `domain` so that it won't be searched for with /etc/resolv.conf's search rules.
      #
      #     GitHubPages::HealthCheck.new("anything.io").absolute_domain
      #     => "anything.io."
      def absolute_domain
        host.end_with?(".") ? host : "#{host}."
      end

      def scheme
        @scheme ||= github_domain? ? "https" : "http"
      end
    end
  end
end
