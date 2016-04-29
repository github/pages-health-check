module GitHubPages
  module HealthCheck
    module Errors
      class BuildError < GitHubPages::HealthCheck::Error
        DOCUMENTATION_PATH = '/articles/troubleshooting-jekyll-builds/'
      end
    end
  end
end
