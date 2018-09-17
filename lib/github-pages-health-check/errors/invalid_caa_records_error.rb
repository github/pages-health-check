# frozen_string_literal: true

module GitHubPages
  module HealthCheck
    module Errors
      class InvalidCAARecordsError < GitHubPages::HealthCheck::Error
        DOCUMENTATION_PATH = "/articles/setting-up-a-custom-domain-with-github-pages/".freeze

        def message
          <<-MSG
             Your site's DNS settings are using CAA records which do not allow
             issuing of Let's Encrypt certificates.
          MSG
        end
      end
    end
  end
end
