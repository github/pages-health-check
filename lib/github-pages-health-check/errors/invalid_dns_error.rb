module GitHubPages
  module HealthCheck
    module Errors
      class InvalidDNSError < GitHubPages::HealthCheck::Error
        # rubocop:disable Metrics/LineLength
        DOCUMENTATION_PATH = "/articles/setting-up-a-custom-domain-with-github-pages/".freeze

        def message
          "Domain's DNS record could not be retrieved"
        end
      end
    end
  end
end
