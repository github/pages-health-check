# frozen_string_literal: true

module GitHubPages
  module HealthCheck
    module Errors
      class InvalidCAARecordError < GitHubPages::HealthCheck::Error
        DOCUMENTATION_PATH = "/articles/troubleshooting-custom-domains/#https-errors".freeze

        def message
          <<-MSG
             Your site's DNS settings are using a custom subdomain, #{domain.host},
             that has CAA records which do not allow for Let's Encrypt. Please include
             a record which allows Let's Encrypt to issue a certificate. Records: #{domain.caa_records}
           MSG
        end
      end
    end
  end
end
