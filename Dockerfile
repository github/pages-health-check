FROM ruby:2.5.1-alpine3.7
RUN apk add --update --no-cache build-base libcurl \
 && gem install github-pages-health-check \
 && apk del build-base \
 && echo "require 'github-pages-health-check'; puts GitHubPages::HealthCheck::Site.new(ARGV[0]).to_json" > to_json.rb
ENTRYPOINT [ "ruby", "to_json.rb" ]