class GitHubPages
  class HealthCheck
    class InvalidDNS < Error
      def message
        "Domain's DNS record could not be retrieved"
      end
    end
  end
end
