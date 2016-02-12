module GitHubPages
  module HealthCheck
    module Errors
      class InvalidDNSError < GitHubPages::HealthCheck::Error
        def message
          "Domain's DNS record could not be retrieved"
        end
      end
    end
  end
end
