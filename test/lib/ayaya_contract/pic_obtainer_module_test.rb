require "test_helper"
require "json"
require "open3"

class AyayaContract::PicObtainerModuleTest < ActiveSupport::TestCase
  test "pic obtainer deployment descriptor uses the registered module contract" do
    environment = {
      "PIC_OBTAINER_IMAGE" => "pic-obtainer:test",
      "PIC_OBTAINER_DATABASE_URL" => "postgresql+psycopg://pic_obtainer:test@postgres:5432/pic_obtainer",
      "PIC_OBTAINER_MEDIA_ROOT" => "/var/lib/pic-obtainer/media",
      "PIC_OBTAINER_MEDIA_HOST_PATH" => "/tmp/pic-obtainer-media",
      "PIC_OBTAINER_IMPORT_ROOT" => "/var/lib/pic-obtainer/imports",
      "PIC_OBTAINER_IMPORT_HOST_PATH" => "/tmp/pic-obtainer-import",
      "PIC_OBTAINER_AYAYA_ADAPTER_SECRET" => "test-secret",
      "PIC_OBTAINER_RULE34_USER_ID" => "12345",
      "PIC_OBTAINER_RULE34_API_KEY" => "test-key"
    }
    stdout, stderr, status = Open3.capture3(
      environment,
      "docker", "compose", "-f", "modules/pic_obtainer/compose.yml", "config", "--format", "json",
      chdir: Rails.root.to_s
    )
    assert status.success?, "docker compose config failed: #{stderr}"

    descriptor = JSON.parse(stdout)
    services = descriptor.fetch("services")
    api = services.fetch("pic_obtainer_api")
    worker = services.fetch("pic_obtainer_worker")

    assert_equal %w[pic_obtainer_api pic_obtainer_worker], services.keys.sort
    assert_equal [
      "uvicorn",
      "pic_obtainer.api.main:create_app",
      "--factory",
      "--host",
      "0.0.0.0",
      "--port",
      "8000"
    ], api.fetch("command")
    assert_nil api["ports"]
    assert_nil worker["ports"]
    refute api.fetch("environment").keys.any? { |key| key.start_with?("PIC_OBTAINER_RULE34_") }
    assert_equal "test-key", worker.fetch("environment").fetch("PIC_OBTAINER_RULE34_API_KEY")
    assert_equal "12345", worker.fetch("environment").fetch("PIC_OBTAINER_RULE34_USER_ID")
    expected_volumes = [
      { "type" => "bind", "source" => "/tmp/pic-obtainer-media", "target" => "/var/lib/pic-obtainer/media" },
      { "type" => "bind", "source" => "/tmp/pic-obtainer-import", "target" => "/var/lib/pic-obtainer/imports", "read_only" => true }
    ]
    normalized_volumes = api.fetch("volumes").map do |volume|
      volume.slice("type", "source", "target", "read_only")
    end
    assert_equal expected_volumes, normalized_volumes
    assert_equal api.fetch("volumes"), worker.fetch("volumes")
    assert_includes File.read("modules/pic_obtainer/README.md"), "pic_obtainer"
    assert_includes File.read("modules/pic_obtainer/README.md"), "/m/pic_obtainer"
  end
end
