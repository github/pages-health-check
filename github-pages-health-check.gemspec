require File.expand_path("../lib/github-pages-health-check/version", __FILE__)

Gem::Specification.new do |s|
  s.required_ruby_version = ">= 1.9.3"

  s.name                  = "github-pages-health-check"
  s.version               = GitHubPages::HealthCheck::VERSION
  s.summary               = "Checks your GitHub Pages site for commons DNS configuration issues"
  s.description           = "Checks your GitHub Pages site for commons DNS configuration issues."
  s.authors               = "GitHub, Inc."
  s.email                 = "support@github.com"
  s.homepage              = "https://github.com/github/github-pages-health-check"
  s.license               = "MIT"
  s.files                 = [
    "lib/github-pages-health-check.rb",
    "lib/github-pages-health-check/version.rb",
    "lib/github-pages-health-check/cloudflare.rb",
    "lib/github-pages-health-check/error.rb",
    "lib/github-pages-health-check/errors/deprecated_ip.rb",
    "lib/github-pages-health-check/errors/invalid_a_record.rb",
    "lib/github-pages-health-check/errors/invalid_cname.rb",
    "lib/github-pages-health-check/errors/not_served_by_pages.rb",
    "config/cloudflare-ips.txt",
    "LICENSE.md"
  ]

  s.add_dependency("net-dns", "~> 0.6")
  s.add_dependency("public_suffix", "~> 1.4")
  s.add_development_dependency("rspec", "~> 3.0")
  s.add_development_dependency("pry")
  s.add_development_dependency("gem-release")

end
