module GitHubPages
  module HealthCheck
    module Errors
      class DeprecatedIPError < GitHubPages::HealthCheck::Error
        def message
          "A record points to deprecated IP address"
        end
      end
    end
  end
end
