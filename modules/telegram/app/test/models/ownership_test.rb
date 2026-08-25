require "test_helper"

class OwnershipTest < ActiveSupport::TestCase
  test "foreign or externally modified folders are immutable" do
    foreign = { "managed_by_app" => false, "ownership_record" => {}, "remote_fingerprint" => "a" }
    changed = { "managed_by_app" => true, "ownership_record" => { "account_id" => "1", "fingerprint" => "before" }, "remote_fingerprint" => "after" }

    refute Telegram::Ownership.mutable?(foreign)
    refute Telegram::Ownership.mutable?(changed)
  end

  test "ownership requires a matching immutable Telegram folder ID" do
    valid = { "telegram_folder_id" => 7, "managed_by_app" => true, "ownership_record" => { "account_id" => "1", "telegram_folder_id" => 7, "fingerprint" => "matched" }, "remote_fingerprint" => "matched" }
    mismatched = valid.deep_merge("ownership_record" => { "telegram_folder_id" => 8 })

    assert Telegram::Ownership.mutable?(valid, account_id: "1")
    refute Telegram::Ownership.mutable?(mismatched, account_id: "1")
  end
end
