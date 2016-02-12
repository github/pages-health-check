module GitHubPages
  module HealthCheck
    class CloudFlare
      include Singleton

      # Internal: The path of the config file.
      attr_reader :path

      # Public: Does cloudflare control this address?
      def self.controls_ip?(address)
        instance.controls_ip?(address)
      end

      # Internal: Create a new cloudflare info instance.
      def initialize(options = {})
        @path = options.fetch(:path) { default_config_path }
      end

      # Internal: Does cloudflare control this address?
      def controls_ip?(address)
        ranges.any? { |range| range.include?(address) }
      end

      private

      # Internal: The IP address ranges that cloudflare controls.
      def ranges
        @ranges ||= load_ranges
      end

      # Internal: Load IPAddr ranges from #path
      def load_ranges
        File.read(path).lines.map { |line| IPAddr.new(line.chomp) }
      end

      def default_config_path
        File.expand_path("../../config/cloudflare-ips.txt", File.dirname(__FILE__))
      end
    end
  end
end
