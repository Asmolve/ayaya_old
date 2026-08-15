require "test_helper"

class AyayaContract::PicObtainerModuleTest < ActiveSupport::TestCase
  test "pic obtainer deployment descriptor uses the registered module contract" do
    descriptor = YAML.safe_load_file("modules/pic_obtainer/compose.yml", aliases: true)
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
    assert_includes worker.fetch("environment").keys, "PIC_OBTAINER_RULE34_API_KEY"
    assert_includes worker.fetch("environment").keys, "PIC_OBTAINER_RULE34_USER_ID"
    assert_equal 2, api.fetch("volumes").length
    assert_equal 2, worker.fetch("volumes").length
    assert_includes File.read("modules/pic_obtainer/README.md"), "pic_obtainer"
    assert_includes File.read("modules/pic_obtainer/README.md"), "/m/pic_obtainer"
  end
end
