module GitHubPages
  module HealthCheck
    class Site < GitHubPages::HealthCheck::Checkable

      attr_reader :repository, :domain

      # Array of symbolized Domain methods to be included in the output hash
      DOMAIN_HASH_METHODS = [
        :host, :uri, :dns_resolves?, :proxied?, :cloudflare_ip?,
        :old_ip_address?, :a_record?, :cname_record?, :valid_domain?,
        :apex_domain?, :should_be_a_record?, :pointed_to_github_user_domain?,
        :pointed_to_github_pages_ip?, :pages_domain?, :served_by_pages?,
        :valid_domain?
      ].freeze

      # Array of symbolized Repository methods to be included in the output hash
      REPOSITORY_HASH_METHODS = [
        :name_with_owner, :built?, :last_built,  :build_duration, :build_error
      ].freeze

      def initialize(repository_or_domain, access_token: nil)
        @repository = Repository.new(repository_or_domain, access_token: access_token)
        @domain = @repository.domain
      rescue GitHubPages::HealthCheck::Errors::InvalidRepositoryError
        @repository = nil
        @domain = Domain.new(repository_or_domain)
      end

      def check!
        domain.check!
        reposity.check! unless repository.nil?
        true
      end

      def to_hash
        hash = {}

        DOMAIN_HASH_METHODS.each do |method|
          hash[method] = domain.send(method)
        end

        unless repository.nil?
          REPOSITORY_HASH_METHODS.each do |method|
            hash[method] = repository.send(method)
          end
        end

        hash[:valid?] = valid?
        hash[:reason] = reason

        hash
      end
      alias_method :to_h, :to_hash
      alias_method :as_json, :to_hash

      def to_json
        as_json.to_json
      end

      def to_s
        to_hash.inject(Array.new) do |all, pair|
          all.push pair.join(": ")
        end.join("\n")
      end
    end
  end
end
