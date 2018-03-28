require 'dnsruby'
require 'public_suffix'

module GitHubPages
  module HealthCheck
    class CAA
      attr_reader :host
      attr_reader :error

      def initialize(host)
        @host = host
      end

      def errored?
        records # load the records first
        !error.nil?
      end

      def lets_encrypt_allowed?
        return false if errored?
        return true unless records_present?
        records.any? { |r| r.property_value == 'letsencrypt.org' }
      end

      def records_present?
        return false if errored?
        records && !records.empty?
      end

      def records
        @records ||= (get_caa_records(host) | get_caa_records(PublicSuffix.domain(host)))
      end

      def get_caa_records(domain)
        resolver = Dnsruby::Resolver.new
        resolver.retry_times = 2
        resolver.query_timeout = 2
        nspack = begin
          resolver.query(domain, 'CAA', 'IN')
        rescue Exception => e
          @error = e
          return []
        end
        nspack.answer.select {|r| r.type == 'CAA' && r.property_tag == 'issue' }
      end
    end
  end
end
