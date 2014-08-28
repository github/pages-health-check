class GitHubPages
  class HealthCheck
    class InvalidCNAME < StandardError
      def message
        "CNAME does not point to GitHub Pages"
      end
    end
  end
end
