module GitHubPages
  module HealthCheck
    module Errors
      class InvalidCNAMEError < GitHubPages::HealthCheck::Error
        def message
          "CNAME does not point to GitHub Pages"
        end
      end
    end
  end
end
