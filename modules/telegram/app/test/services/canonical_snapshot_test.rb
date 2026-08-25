require "test_helper"

class CanonicalSnapshotTest < ActiveSupport::TestCase
  test "normalizes hash order but preserves Telegram order vectors" do
    left = Telegram::CanonicalSnapshot.build(account_id: "42", folders: [ { id: 1, include: [ 3, 2 ] } ], limits: { chats: 100, folders: 10 })
    right = Telegram::CanonicalSnapshot.build(limits: { folders: 10, chats: 100 }, folders: [ { include: [ 3, 2 ], id: 1 } ], account_id: "42")

    assert_equal left.payload, right.payload
    assert_equal left.source_hash, right.source_hash
  end

  test "changes the fingerprint when a folder or include vector is reordered" do
    first = Telegram::CanonicalSnapshot.build(folders: [ { id: 1 }, { id: 2 } ], include: [ "a", "b" ])
    reordered = Telegram::CanonicalSnapshot.build(folders: [ { id: 2 }, { id: 1 } ], include: [ "b", "a" ])

    assert_not_equal first.source_hash, reordered.source_hash
  end

  test "sorts only explicitly declared set-like collections" do
    left = Telegram::CanonicalSnapshot.build(labels: %w[work family], canonical_set_paths: [ "labels" ])
    right = Telegram::CanonicalSnapshot.build(labels: %w[family work], canonical_set_paths: [ "labels" ])

    assert_equal left.source_hash, right.source_hash
  end
end
