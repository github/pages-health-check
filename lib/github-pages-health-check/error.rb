module GitHubPages
  module HealthCheck
    class Error < StandardError
      DOCUMENTATION_BASE = "https://help.github.com"

      attr_reader :repository, :domain

      def initialize(repository: nil, domain: nil)
        super
        @repository = repository
        @domain     = domain
      end

      def self.inherited(base)
        subclasses << base
      end

      def self.subclasses
        @subclasses ||= []
      end

      def message_formatted
        "#{message.gsub(/\s+/, " ").strip} #{more_info}"
      end

      private

      def username
        if repository.nil?
          "[YOUR USERNAME]"
        else
          repository.owner
        end
      end

      def more_info
        "For more information, see #{documentation_url}."
      end

      def documentation_url
        URI.join(Error::DOCUMENTATION_BASE, self.class::DOCUMENTATION_PATH).to_s
      end
    end
  end
end
