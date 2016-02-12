module GitHubPages
  module HealthCheck
    module Errors
      class InvalidARecordError < GitHubPages::HealthCheck::Error
        def message
          "Should not be an A record"
        end
      end
    end
  end
end
