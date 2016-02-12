module GitHubPages
  module HealthCheck
    module Errors
      class InvalidDomainError < GitHubPages::HealthCheck::Error
        def message
          "Domain is not a valid domain"
        end
      end
    end
  end
end
