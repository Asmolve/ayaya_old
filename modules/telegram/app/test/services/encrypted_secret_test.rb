require "test_helper"

class EncryptedSecretTest < ActiveSupport::TestCase
  test "encrypts with an authenticated envelope without retaining plaintext" do
    key_provider = Telegram::StaticKeyProvider.new("v1", "a" * 32)
    envelope = Telegram::EncryptedSecret.encrypt("session-value", key_provider: key_provider)

    refute_includes envelope.to_json, "session-value"
    assert_equal "session-value", Telegram::EncryptedSecret.decrypt(envelope, key_provider: key_provider)
  end

  test "fails closed when the referenced key is unavailable" do
    envelope = { "key_id" => "missing", "nonce" => "x", "ciphertext" => "x", "tag" => "x" }

    assert_raises(Telegram::KeyUnavailable) { Telegram::EncryptedSecret.decrypt(envelope, key_provider: Telegram::StaticKeyProvider.new("v1", "a" * 32)) }
  end
end
