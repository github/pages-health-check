module GitHubPages
  module HealthCheck
    class Error < StandardError
      def self.inherited(base)
        subclasses << base
      end

      def self.subclasses
        @subclasses ||= []
      end
    end
  end
end
