require "test_helper"

class DockerImageTest < ActiveSupport::TestCase
  test "production image builds gems in a dedicated build stage" do
    dockerfile = Rails.root.join("Dockerfile").read

    assert_includes dockerfile, "FROM ruby:$RUBY_VERSION-slim AS base"
    assert_includes dockerfile, "FROM base AS build"
    assert_includes dockerfile, "build-essential git libpq-dev pkg-config"
    assert_includes dockerfile, "FROM base AS production"
    assert_includes dockerfile, "COPY --chown=rails:rails --from=build"
    assert_includes dockerfile, 'CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]'
  end

  test "lockfile supports the Linux production image platform" do
    lockfile = Rails.root.join("Gemfile.lock").read

    assert_includes lockfile, "nokogiri (1.19.4-aarch64-linux-gnu)"
    assert_match(/^  aarch64-linux$/m, lockfile)
  end
end
