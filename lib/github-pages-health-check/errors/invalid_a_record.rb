class GitHubPages
  class HealthCheck
    class InvalidARecord < StandardError
      def message
        "Should not be an A record"
      end
    end
  end
end
