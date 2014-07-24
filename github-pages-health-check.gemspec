require File.expand_path('../lib/github-pages-health-check/version', __FILE__)

Gem::Specification.new do |s|
  s.required_ruby_version = ">= 1.9.3"

  s.name                  = "github-pages-health-check"
  s.version               = GitHubPages::HealthCheck::VERSION
  s.summary               = ""
  s.description           = ""
  s.authors               = "GitHub, Inc."
  s.email                 = "support@github.com"
  s.homepage              = "https://github.com/github/github-pages-health-check"
  s.license               = "MIT"
  s.files                 = [
    "lib/github-pages-health-check.rb",
    "lib/github-pages-health-check/version.rb"
  ]

  s.add_dependency("net-dns", "~> 0.6")
  s.add_dependency("public_suffix", "~> 1.4")
  s.add_development_dependency("rspec", "~> 2.14")
  s.add_development_dependency("pry")

end
