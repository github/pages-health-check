ARG RUBY_VERSION
FROM ruby:$RUBY_VERSION-slim
RUN set -ex \
    # Update RubyGems system if Ruby version is 3.1 or higher
    && if ruby -e 'exit(RUBY_VERSION.to_f >= 3.1)'; then \
         gem update --system; \
       fi \
    && apt-get update -y \
    && apt-get upgrade -y \
    && apt-get install -y build-essential git libcurl4-openssl-dev \
    && apt-get clean
WORKDIR /app/github-pages-health-check
COPY Gemfile .
COPY github-pages-health-check.gemspec .
COPY lib/github-pages-health-check/version.rb lib/github-pages-health-check/version.rb
RUN bundle install
COPY . .
ENTRYPOINT [ "/bin/bash" ]
