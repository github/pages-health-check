module GitHubPages
  module HealthCheck
    class Printer
      PRETTY_LEFT_WIDTH = 11
      PRETTY_JOINER = " | "

      attr_reader :health_check

      def initialize(health_check)
        @health_check = health_check
      end

      def simple_string
        require 'yaml'
        hash = health_check.to_hash
        hash[:reason] = hash[:reason].to_s if hash[:reason]
        hash.to_yaml.sub(/\A---\n/, "").gsub(/^:/, "")
      end

      def pretty_print
        values = health_check.to_hash
        output = StringIO.new

        # Header
        output.puts new_line "Domain", "#{values[:uri]}"
        output.puts ("-" * (PRETTY_LEFT_WIDTH + 1)) + "|" + "-" * 50

        output.puts new_line "DNS", "does not resolve" if not values[:dns_resolves?]

        # Valid?
        output.write new_line "State", "#{values[:valid?] ? "valid" : "invalid"}"
        output.puts " - is #{"NOT " if not values[:served_by_pages?]}served by Pages"

        # What's wrong?
        output.puts new_line "Reason", "#{values[:reason]}" if not values[:valid?]
        output.puts new_line nil, "pointed to user domain"  if values[:pointed_to_github_user_domain?]
        output.puts new_line nil, "pointed to pages IP"     if values[:pointed_to_github_pages_ip?]

        # DNS Record info
        output.write new_line "Record Type", "#{values[:a_record?] ? "A" : values[:cname_record?] ? "CNAME" : "other"}"
        output.puts values[:should_be_a_record?] ? ", should be A record" : ", should be CNAME"

        ip_problems = []
        ip_problems << "not apex domain" if not values[:apex_domain?]
        ip_problems << "invalid domain" if not values[:valid_domain?]
        ip_problems << "old ip address used" if values[:old_ip_address?]
        output.puts new_line "IP Problems", "#{ip_problems.size > 0 ? ip_problems.join(", ") : "none"} "

        if values[:proxied?]
          output.puts new_line "Proxied", "yes, through #{values[:cloudflare_ip?] ? "CloudFlare" : "unknown"}"
        end

        output.puts new_line "Domain", "*.github.com/io domain" if values[:pages_domain?]

        output.string
      end

      def new_line(left = nil, right = nil)
        if left and right
          ljust(left) + PRETTY_JOINER + right
        elsif left
          ljust(left)
        elsif right
          " " * (PRETTY_LEFT_WIDTH + PRETTY_JOINER.size) + right
        end
      end

      def ljust(line)
        line.ljust(PRETTY_LEFT_WIDTH)
      end
    end
  end
end
