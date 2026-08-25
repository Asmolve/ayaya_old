require "test_helper"

class TaskTenFilterFidelityTest < ActiveSupport::TestCase
  test "canonical filters preserve remote vector order, flags, and unrecognized filter fields" do
    filter = {
      "telegram_folder_id" => 7,
      "title" => "Work",
      "include_peers" => [ { "id" => "2", "kind" => "channel" }, { "id" => "1", "kind" => "user" } ],
      "exclude_peers" => [ { "id" => "9", "kind" => "bot" }, { "id" => "8", "kind" => "channel" } ],
      "pinned_peers" => [ { "id" => "1", "kind" => "user" }, { "id" => "2", "kind" => "channel" } ],
      "flags" => { "contacts" => true, "groups" => false, "exclude_archived" => true },
      "custom_server_flag" => "retain-me"
    }

    canonical = Telegram::FilterState.canonical(filter)

    assert_equal filter.fetch("include_peers"), canonical.fetch("include_peers")
    assert_equal filter.fetch("exclude_peers"), canonical.fetch("exclude_peers")
    assert_equal filter.fetch("pinned_peers"), canonical.fetch("pinned_peers")
    assert_equal filter.fetch("flags"), canonical.fetch("flags")
    assert_equal "retain-me", canonical.fetch("custom_server_flag")
  end

  test "import snapshots retain complete canonical remote context" do
    account = TelegramAccount.create!(module_user: ModuleUser.create!(core_user_id: "snapshot-context"), telegram_account_id: "snapshot-context")
    state = {
      "folder_order" => [ 9, 7 ],
      "folders" => [
        {
          "telegram_folder_id" => 7,
          "title" => "Work",
          "include_peers" => [ { "id" => "2", "kind" => "channel" }, { "id" => "1", "kind" => "user" } ],
          "exclude_peers" => [ { "id" => "8", "kind" => "bot" } ],
          "pinned_peers" => [ { "id" => "1", "kind" => "user" } ],
          "flags" => { "contacts" => true, "groups" => false },
          "remote_fingerprint" => "foreign-7"
        }
      ],
      "dialogs" => [ { "peer_kind" => "channel", "peer_id" => "2", "input_peer_ref" => { "id" => "2", "kind" => "channel", "access_hash" => "live" }, "title" => "Channel", "username" => "channel", "metadata_hash" => "meta" } ],
      "app_config" => { "entitlement" => "premium", "dialog_filters_limit_premium" => 20, "dialog_filters_chats_limit_premium" => 200, "dialogs_folder_pinned_limit_premium" => 7, "dialog_filters_title_length_limit_premium" => 12 }
    }

    Telegram::ReadOnlyImport.new(account: account, client: Telegram::TestClient.new(remote_state: state)).call

    payload = account.snapshots.find_by!(kind: "import").payload_data
    assert_equal [ 9, 7 ], payload["folder_order"]
    filter = payload.fetch("filters").first
    assert_equal state.fetch("folders").first.fetch("include_peers"), filter.fetch("include_peers")
    assert_equal state.fetch("folders").first.fetch("exclude_peers"), filter.fetch("exclude_peers")
    assert_equal state.fetch("folders").first.fetch("pinned_peers"), filter.fetch("pinned_peers")
    assert_equal state.fetch("folders").first.fetch("flags"), filter.fetch("flags")
    assert_equal state.fetch("app_config"), payload["app_config"]
    assert_equal state.fetch("dialogs").first.fetch("input_peer_ref"), payload.fetch("dialogs").first.fetch("input_peer_ref")
  end

  test "detailed diffs expose every changed filter vector and flag without reordering it" do
    current = {
      "telegram_folder_id" => 1,
      "title" => "Work",
      "include_peers" => [ { "id" => "1", "kind" => "user" }, { "id" => "2", "kind" => "channel" } ],
      "exclude_peers" => [ { "id" => "9", "kind" => "bot" } ],
      "pinned_peers" => [ { "id" => "1", "kind" => "user" } ],
      "flags" => { "contacts" => true, "groups" => false }
    }
    desired = current.deep_merge(
      "include_peers" => [ { "id" => "2", "kind" => "channel" }, { "id" => "1", "kind" => "user" } ],
      "exclude_peers" => [ { "id" => "8", "kind" => "channel" } ],
      "pinned_peers" => [ { "id" => "2", "kind" => "channel" } ],
      "flags" => { "contacts" => false, "groups" => true }
    )

    detail = Telegram::Planner.new(current_folders: [ current ], desired_folders: [ desired ], account_id: "account").detailed_diff.fetch(0)

    assert_equal desired.fetch("flags"), detail.dig("fields", "flags", "to")
    assert_equal desired.fetch("exclude_peers"), detail.dig("fields", "exclude_peers", "to")
    assert_equal desired.fetch("pinned_peers"), detail.dig("fields", "pinned_peers", "to")
    assert_equal desired.fetch("include_peers"), detail.dig("fields", "include_peers", "to")
    assert detail.fetch("order_changed")
  end
end
