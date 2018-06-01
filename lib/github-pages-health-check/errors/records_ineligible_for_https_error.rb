# frozen_string_literal: true

module GitHubPages
  module HealthCheck
    module Errors
      class RecordsIneligibleForHTTPSError < GitHubPages::HealthCheck::Error
        DOCUMENTATION_PATH = "/articles/setting-up-a-custom-domain-with-github-pages/".freeze

        def message
          "Domain does not resolve to the GitHub Pages servers which are eligible for HTTPS"
        end
      end
    end
  end
end
