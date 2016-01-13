require "net/dns"
require "net/dns/resolver"
require "addressable/uri"
require "ipaddr"
require "public_suffix"
require "singleton"
require "net/http"
require "typhoeus"
require "resolv"
require "timeout"
require_relative "github-pages-health-check/version"
require_relative "github-pages-health-check/cloudflare"
require_relative "github-pages-health-check/error"
require_relative "github-pages-health-check/errors/deprecated_ip"
require_relative "github-pages-health-check/errors/invalid_a_record"
require_relative "github-pages-health-check/errors/invalid_cname"
require_relative "github-pages-health-check/errors/invalid_dns"
require_relative "github-pages-health-check/errors/not_served_by_pages"

class GitHubPages
  class HealthCheck

    attr_accessor :domain

    LEGACY_IP_ADDRESSES = %w[
      207.97.227.245
      204.232.175.78
      199.27.73.133
    ]

    CURRENT_IP_ADDRESSES = %w[
      192.30.252.153
      192.30.252.154
    ]

    # DNS and HTTP timeout, in seconds
    TIMEOUT = 10

    TYPHOEUS_OPTIONS = {
      :followlocation  => true,
      :timeout         => TIMEOUT,
      :accept_encoding => "gzip",
      :method          => :head,
      :headers         => {
        "User-Agent"   => "Mozilla/5.0 (compatible; GitHub Pages Health Check/#{VERSION}; +https://github.com/github/pages-health-check)"
      }
    }

    def initialize(domain)
      @domain = domain
    end

    def cloudflare_ip?
      dns.all? do |answer|
        answer.class == Net::DNS::RR::A && CloudFlare.controls_ip?(answer.address)
      end if dns?
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
      if @dns.nil?
        begin
          @dns = Timeout::timeout(TIMEOUT) do
            without_warnings do
              Net::DNS::Resolver.start(absolute_domain).answer if domain
            end
          end
          @dns ||= false
        rescue Exception
          @dns = false
        end
      end
      @dns || nil
    end

    # Are we even able to get the DNS record?
    def dns?
      !dns.nil? && !dns.empty?
    end
    alias_method :dns_resolves?, :dns

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

    # Is this a valid domain that PublicSuffix recognizes?
    # Used as an escape hatch to prevent false positives on DNS checkes
    def valid_domain?
      PublicSuffix.valid? domain
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
    def pages_domain?(domain = domain())
      !!domain.match(/^[\w-]+\.github\.(io|com)\.?$/i)
    end

    # Is this domain owned by GitHub?
    def github_domain?
      !!domain.match(/\.github\.com$/)
    end

    def to_hash
      {
        :uri                            => uri.to_s,
        :dns_resolves?                  => dns?,
        :proxied?                       => proxied?,
        :cloudflare_ip?                 => cloudflare_ip?,
        :old_ip_address?                => old_ip_address?,
        :a_record?                      => a_record?,
        :cname_record?                  => cname_record?,
        :valid_domain?                  => valid_domain?,
        :apex_domain?                   => apex_domain?,
        :should_be_a_record?            => should_be_a_record?,
        :pointed_to_github_user_domain? => pointed_to_github_user_domain?,
        :pointed_to_github_pages_ip?    => pointed_to_github_pages_ip?,
        :pages_domain?                  => pages_domain?,
        :served_by_pages?               => served_by_pages?,
        :valid?                         => valid?,
        :reason                         => reason
      }
    end
    alias_method :to_h, :to_hash

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

    def to_json
      to_hash.to_json
    end

    # Runs all checks, raises an error if invalid
    def check!
      raise InvalidDNS unless dns?
      return if proxied?
      raise DeprecatedIP if a_record? && old_ip_address?
      raise InvalidARecord if valid_domain? && a_record? && !should_be_a_record?
      raise InvalidCNAME if valid_domain? && !github_domain? && !apex_domain? && !pointed_to_github_user_domain?
      raise NotServedByPages unless served_by_pages?
      true
    end
    alias_method :valid!, :check!

    # Runs all checks, returns true if valid, otherwise false
    def valid?
      check!
      true
    rescue
      false
    end

    # Return the error, if any
    def reason
      check!
      nil
    rescue GitHubPages::HealthCheck::Error => e
      e
    end

    def inspect
      "#<GitHubPages::HealthCheck @domain=\"#{domain}\" valid?=#{valid?}>"
    end

    def to_s
      to_hash.inject(Array.new) do |all, pair|
        all.push pair.join(": ")
      end.join("\n")
    end

    private

    # surpress warn-level feedback due to unsupported record types
    def without_warnings(&block)
      warn_level, $VERBOSE = $VERBOSE, nil
      result = block.call
      $VERBOSE = warn_level
      result
    end

    # Adjust `domain` so that it won't be searched for with /etc/resolv.conf's search rules.
    #
    #     GitHubPages::HealthCheck.new("anything.io").absolute_domain
    #     => "anything.io."
    def absolute_domain
      domain.end_with?(".") ? domain : "#{domain}."
    end

    def scheme
      @scheme ||= github_domain? ? "https" : "http"
    end

    def uri
      @uri ||= Addressable::URI.new(:host => domain, :scheme => scheme, :path => "/").normalize
    end
  end
end
