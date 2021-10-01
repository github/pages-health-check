# frozen_string_literal: true

module GitHubPages
  module HealthCheck
    module Errors
      class InvalidAAAARecordError < GitHubPages::HealthCheck::Error
        DOCUMENTATION_PATH = "/articles/setting-up-a-custom-domain-with-github-pages/"

        def message
          <<-MSG
             Your site's DNS settings are using a custom subdomain, #{domain.host},
             that's not setup with the correct AAAA record. The AAAA record for your apex 
             domain must point to the IP addresses for GitHub Pages.
          MSG
        end
      end
    end
  end
end
