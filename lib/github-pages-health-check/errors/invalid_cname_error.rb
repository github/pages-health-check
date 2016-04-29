module GitHubPages
  module HealthCheck
    module Errors
      class InvalidCNAMEError < GitHubPages::HealthCheck::Error
        # rubocop:disable Metrics/LineLength
        DOCUMENTATION_PATH = "/articles/setting-up-a-custom-domain-with-github-pages/".freeze

        def message
          <<-MSG
             Your site's DNS settings are using a custom subdomain, #{domain.host},
             that's not set up with a correct CNAME record.  We recommend you set this
             CNAME record to point at #{username}.github.io.
           MSG
        end
      end
    end
  end
end
