module GitHubPages
  module HealthCheck
    class Checkable

      def check!
        raise "Not implemented"
      end
      alias_method :valid!, :check!

      # Runs all checks, returns true if valid, otherwise false
      def valid?
        check!
        true
      rescue GitHubPages::HealthCheck::Error
        false
      end

      # Returns the reason the check failed, if any
      def reason
        check!
        nil
      rescue GitHubPages::HealthCheck::Error => e
        e
      end
    end
  end
end
