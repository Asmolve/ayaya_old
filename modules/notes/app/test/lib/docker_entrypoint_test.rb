require "test_helper"
require "fileutils"
require "open3"
require "tmpdir"

class DockerEntrypointTest < ActiveSupport::TestCase
  test "prepares the database before starting the rails server" do
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "bin"))
      log_path = File.join(dir, "rails.log")
      rails_path = File.join(dir, "bin", "rails")

      File.write(rails_path, <<~SH)
        #!/bin/sh
        echo "$@" >> "#{log_path}"
      SH
      FileUtils.chmod("+x", rails_path)

      script_path = Rails.root.join("bin/docker-entrypoint")
      stdout, stderr, status = Open3.capture3(
        "bash",
        script_path.to_s,
        "./bin/rails",
        "server",
        chdir: dir,
      )

      assert_predicate status, :success?, "stdout: #{stdout}\nstderr: #{stderr}"
      assert_equal [ "db:prepare", "server" ], File.readlines(log_path, chomp: true)
    end
  end

  test "prepares the database before starting the compose rails server command" do
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "bin"))
      FileUtils.mkdir_p(File.join(dir, "tmp/pids"))
      log_path = File.join(dir, "rails.log")
      rails_path = File.join(dir, "bin", "rails")

      File.write(rails_path, <<~SH)
        #!/bin/sh
        echo "$@" >> "#{log_path}"
      SH
      FileUtils.chmod("+x", rails_path)

      script_path = Rails.root.join("bin/docker-entrypoint")
      stdout, stderr, status = Open3.capture3(
        "bash",
        script_path.to_s,
        "sh",
        "-lc",
        "rm -f tmp/pids/server.pid && bin/rails server -b 0.0.0.0 -p 3000",
        chdir: dir,
      )

      assert_predicate status, :success?, "stdout: #{stdout}\nstderr: #{stderr}"
      assert_equal [ "db:prepare", "server -b 0.0.0.0 -p 3000" ], File.readlines(log_path, chomp: true)
    end
  end
end
