module GitHubPages
  module HealthCheck
    class Checkable

      # Array of symbolized methods to be included in the output hash
      HASH_METHODS = []

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

      def to_hash
        @hash ||= begin
          hash = {}
          self.class::HASH_METHODS.each do |method|
            hash[method] = public_send(method)
          end
          hash
        end
      end
      alias_method :[], :to_hash
      alias_method :to_h, :to_hash

      def to_json
        to_hash.to_json
      end

      def to_s
        to_hash.inject(Array.new) do |all, pair|
          all.push pair.join(": ")
        end.join("\n")
      end
    end
  end
end
