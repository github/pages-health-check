class GitHubPages
  class HealthCheck
    class NotServedByPages < Error
      def message
        "Domain does not resovle to the GitHub Pages server"
      end
    end
  end
end
