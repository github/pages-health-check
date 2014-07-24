require 'net/dns'
require 'net/dns/resolver'
require 'ipaddr'
require 'public_suffix'
require_relative 'github-pages-health-check/version'

class GitHubPages
  class HealthCheck
    class DeprecatedIP < StandardError; end
    class InvalidARecord < StandardError; end
    class InvalidCNAME < StandardError; end

    attr_accessor :domain

    LEGACY_IP_ADDRESSES = %w[
      207.97.227.245
      204.232.175.78
      199.27.73.133
    ]

    CLOUDFLARE_v4 = IPAddr.new("108.162.192.0/18")

    def initialize(domain)
      @domain = domain
    end

    def cloudflare_ip?
      dns.all? { |answer| answer.class == Net::DNS::RR::A && CLOUDFLARE_v4.include?(answer.address.to_s) }
    end

    # Returns an array of DNS answers
    def dns
      @dns ||= Net::DNS::Resolver.start(domain).answer if domain
    rescue Exception => msg
      false
    end

    # Does this domain have *any* A record that points to the legacy IPs?
    def old_ip_address?
      dns.any? { |answer| answer.class == Net::DNS::RR::A && LEGACY_IP_ADDRESSES.include?(answer.address.to_s) }
    end

    # Is this domain's first response an A record?
    def a_record?
      dns.first.class == Net::DNS::RR::A
    end

    # Is this domain's first response a CNAME record?
    def cname_record?
      dns.first.class == Net::DNS::RR::CNAME
    end

    # Is this a valid domain that PublicSuffix recognizes?
    # Used as an escape hatch to prevent false positves on DNS checkes
    def valid_domain?
      PublicSuffix.valid? domain
    end

    # Is this domain an SLD, meaning a CNAME would be innapropriate
    def apex_domain?
      PublicSuffix.parse(domain).trd == nil
    rescue
      false
    end

    # Should the domain be an apex record?
    def should_be_a_record?
      !pages_domain? && apex_domain?
    end

    # Is the domain's first response a CNAME to a pages domain?
    def pointed_to_github_user_domain?
      dns.first.class == Net::DNS::RR::CNAME && pages_domain?(dns.first.cname.to_s)
    end

    # Is the given cname a pages domain?
    #
    # domain - the domain to check, generaly the target of a cname
    def pages_domain?(domain = domain)
      !!domain.match(/^[\w-]+\.github\.(io|com)\.?$/i)
    end

    def to_hash
      {
        :cloudflare_ip?                 => cloudflare_ip?,
        :old_ip_address?                => old_ip_address?,
        :a_record?                      => a_record?,
        :cname_record?                  => cname_record?,
        :valid_domain?                  => valid_domain?,
        :apex_domain?                   => apex_domain?,
        :should_be_a_record?            => should_be_a_record?,
        :pointed_to_github_user_domain? => pointed_to_github_user_domain?,
        :pages_domain?                  => pages_domain?,
        :valid?                         => valid?
      }
    end

    def to_json
      to_hash.to_json
    end

    def check!
      return unless dns
      return if cloudflare_ip?
      raise DeprecatedIP if a_record? && old_ip_address?
      raise InvalidARecord if valid_domain? && a_record? && !should_be_a_record?
      raise InvalidCNAME if valid_domain? && !apex_domain? && !pointed_to_github_user_domain?
    end
    alias_method :valid!, :check!

    def valid?
      check!
      true
    rescue
      false
    end

    def inspect
      "#<GitHubPages::HealthCheck @domain=\"#{domain}\" valid?=#{valid?}>"
    end
  end
end
