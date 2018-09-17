# frozen_string_literal: true

module GitHubPages
  module HealthCheck
    module Errors
      class InvalidIPsPresentError < GitHubPages::HealthCheck::Error
        DOCUMENTATION_PATH = "/articles/setting-up-a-custom-domain-with-github-pages/".freeze

        def message
          <<-MSG
             Your site's DNS settings have A records which point to IPs other
             than GitHub's. We recommend you remove all IPs which are not in this list:
             #{GitHubPages::HealthCheck::Domain::CURRENT_IP_ADDRESSES.join(", ")}.
          MSG
        end
      end
    end
  end
end
