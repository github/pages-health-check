module GitHubPages
  module HealthCheck
    module Errors
      class InvalidRepositoryError < GitHubPages::HealthCheck::Error
        def message
          "Repository is not a valid repository"
        end
      end
    end
  end
end
