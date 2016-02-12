module GitHubPages
  module HealthCheck
    class Domain < Checkable

      attr_reader :host

      LEGACY_IP_ADDRESSES = %w[
        207.97.227.245
        204.232.175.78
        199.27.73.133
      ]

      CURRENT_IP_ADDRESSES = %w[
        192.30.252.153
        192.30.252.154
      ]

      def initialize(host)
        @host = host_from_uri(host)
      end

      # Runs all checks, raises an error if invalid
      def check!
        raise Errors::InvalidDNSError unless dns_resolves?
        return true if proxied?
        raise Errors::DeprecatedIPError if deprecated_ip?
        raise Errors::InvalidARecord    if invalid_a_record?
        raise Errors::InvalidCNAME      if invalid_cname?
        raise Errors::NotServedByPages  unless served_by_pages?
        true
      end

      def deprecated_ip?
        return @deprecated_ip if defined? @deprecated_ip
        @deprecated_ip = a_record? && old_ip_address?
      end

      def invalid_a_record?
        return @invalid_a_record if defined? @invalid_a_record
        @invalid_a_record = valid_domain? && a_record? && !should_be_a_record?
      end

      def invalid_cname?
        return @invalid_cname if defined? @invalid_cname
        @invalid_cname = begin
          return false unless valid_domain?
          !github_domain? && !apex_domain? && !pointed_to_github_user_domain?
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

        answers = Resolv::DNS.open { |dns|
          dns.getresources(absolute_domain, Resolv::DNS::Resource::IN::NS)
        }

        @apex_domain = answers.any?
      end

      # Should the domain be an apex record?
      def should_be_a_record?
        !pages_domain? && apex_domain?
      end

      # Is the domain's first response a CNAME to a pages domain?
      def pointed_to_github_user_domain?
        dns.first.class == Net::DNS::RR::CNAME && pages_domain?(dns.first.cname.to_s) if dns?
      end

      # Is the domain's first response an A record to a valid GitHub Pages IP?
      def pointed_to_github_pages_ip?
        dns.first.class == Net::DNS::RR::A && CURRENT_IP_ADDRESSES.include?(dns.first.value) if dns?
      end

      # Is the given cname a pages domain?
      #
      # domain - the domain to check, generaly the target of a cname
      def pages_domain?(domain = nil)
        domain ||= host
        !!domain.match(/^[\w-]+\.github\.(io|com)\.?$/i)
      end

      # Is this domain owned by GitHub?
      def github_domain?
        !!host.match(/\.github\.com$/)
      end

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
        return false if pointed_to_github_pages_ip? || pointed_to_github_user_domain?
        served_by_pages?
      end

      # Returns an array of DNS answers
      def dns
        return @dns if defined? @dns
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
        dns.first.class == Net::DNS::RR::A if dns?
      end

      # Is this domain's first response a CNAME record?
      def cname_record?
        dns.first.class == Net::DNS::RR::CNAME if dns?
      end

      def served_by_pages?
        return @served_by_pages if defined? @served_by_pages

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
      #   host_from_uri("benbalter.github.com")
      #   # => 'benbalter.github.com'
      #   host_from_uri("https://benbalter.github.com")
      #   # => 'benbalter.github.com'
      #   host_from_uri("benbalter.github.com/help-me-im-a-path/")
      #   # => 'benbalter.github.com'
      #
      # Return the hostname.
      def host_from_uri(domain)
        Addressable::URI.parse(domain).host || Addressable::URI.parse("http://#{domain}").host
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
