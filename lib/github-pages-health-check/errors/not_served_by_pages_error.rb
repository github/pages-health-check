module GitHubPages
  module HealthCheck
    module Errors
      class NotServedByPagesError < GitHubPages::HealthCheck::Error
        def message
          "Domain does not resolve to the GitHub Pages server"
        end
      end
    end
  end
end
