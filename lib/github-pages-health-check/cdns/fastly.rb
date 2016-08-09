module GitHubPages
  module HealthCheck
    # Instance of the Fastly CDN for checking IP ownership
    # Specifically not namespaced to avoid a breaking change
    class Fastly < CDN
    end
  end
end
