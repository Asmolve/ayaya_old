require "test_helper"

class DisconnectAccountTest < ActiveSupport::TestCase
  test "revokes the remote session then clears encrypted credentials and retained account data" do
    user = ModuleUser.create!(core_user_id: "1")
    account = TelegramAccount.create!(module_user: user, telegram_account_id: "account", encrypted_session: { "ciphertext" => "opaque" }, encrypted_api_credentials: { "ciphertext" => "opaque" })
    Dialog.create!(telegram_account: account, peer_kind: "user", peer_id: "1", title: "Private", metadata_hash: "metadata")
    client = Telegram::TestClient.new

    Telegram::DisconnectAccount.new(account: account, client: client).call

    assert_includes client.mutations, { "revoke_session" => true }
    assert_nil account.reload.encrypted_session
    assert_nil account.encrypted_api_credentials
    assert_predicate account, :disconnected_at?
    assert_empty account.dialogs
  end
end
