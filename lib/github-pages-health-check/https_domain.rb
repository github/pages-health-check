# frozen_string_literal: true

module GitHubPages
  module HealthCheck
    class HTTPSDomain < Domain

      def check!
        super
        raise Errors::InvalidIPsPresentError, :domain => self unless cname_to_github_user_domain? || pointed_to_github_pages_ip?
        raise Errors::InvalidAAAARecordError, :domain => self if aaaa_record_present?
        raise Errors::InvalidIPsPresentError, :domain => self if non_github_pages_ip_present?
        raise Errors::InvalidCAARecordsError, :domain => self if caa_error || !caa.lets_encrypt_allowed?
      end

      alias_method :https_eligible?, :valid?

      # Any errors querying CAA records
      def caa_error
        return nil unless caa.errored?
        caa.error.class.name
      end

      def caa
        @caa ||= GitHubPages::HealthCheck::CAA.new(host, :nameservers => nameservers)
      end

    end
  end
end
