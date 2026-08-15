require "test_helper"

class AyayaContract::PicObtainerModuleTest < ActiveSupport::TestCase
  test "pic obtainer deployment descriptor uses the registered module contract" do
    descriptor = YAML.safe_load_file("modules/pic_obtainer/compose.yml", aliases: true)

    assert_equal %w[pic_obtainer_api pic_obtainer_worker], descriptor.fetch("services").keys.sort
    assert_includes File.read("modules/pic_obtainer/README.md"), "pic_obtainer"
    assert_includes File.read("modules/pic_obtainer/README.md"), "/m/pic_obtainer"
  end
end
