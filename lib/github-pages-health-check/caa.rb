# frozen_string_literal: true

require "dnsruby"
require "public_suffix"
require "github-pages-health-check/resolver"

module GitHubPages
  module HealthCheck
    class CAA
      attr_reader :host, :error, :nameservers

      def initialize(host, nameservers: :default)
        raise ArgumentError, "host cannot be nil" if host.nil?

        @host = host
        @nameservers = nameservers
      end

      def errored?
        records # load the records first
        !error.nil?
      end

      def lets_encrypt_allowed?
        return false if errored?
        return true unless records_present?

        records.any? { |r| r.property_value == "letsencrypt.org" }
      end

      def records_present?
        return false if errored?

        records && !records.empty?
      end

      def records
        @records ||= get_caa_records(host)
      end

      def parent_domain_allows_lets_encrypt?
        @parent_domain_allows_lets_encrypt ||= begin
          self.class.new(host.split(".").drop(1).join("."), :nameservers => nameservers)
            .lets_encrypt_allowed?
        end
      end

      private

      def get_caa_records(domain)
        return [] if domain.nil?

        query(domain).select { |r| issue_caa_record?(r) }
      end

      def issue_caa_record?(record)
        record.type == Dnsruby::Types::CAA && record.property_tag == "issue"
      end

      def query(domain)
        resolver(domain).query(Dnsruby::Types::CAA)
      rescue Dnsruby::ResolvError, Dnsruby::ResolvTimeout => e
        @error = e
        []
      end

      def resolver(domain)
        GitHubPages::HealthCheck::Resolver.new(domain, :nameservers => nameservers)
      end
    end
  end
end
