FROM ruby:3.4.4-slim

WORKDIR /rails

RUN apt-get update -qq && apt-get install --no-install-recommends -y build-essential chromium chromium-driver libpq-dev && rm -rf /var/lib/apt/lists/*

COPY Gemfile Gemfile.lock ./
RUN test -s Gemfile.lock && bundle config set frozen true && bundle install

COPY . .

ENTRYPOINT ["/rails/bin/docker-entrypoint"]
EXPOSE 3000
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
