require "test_helper"

class NoteTest < ActiveSupport::TestCase
  test "requires owner and title" do
    note = Note.new(body: "Body")

    assert_not note.valid?
    assert_includes note.errors[:local_user], "must exist"
    assert_includes note.errors[:title], "can't be blank"
  end

  test "diary requires an ordered inclusive range and allows a partial overlap" do
    user = LocalUser.create!(core_user_id: "diary-owner")
    Note.create!(local_user: user, title: "Week", entry_type: :diary,
                 start_date: Date.new(2026, 9, 7), end_date: Date.new(2026, 9, 13))
    overlap = Note.new(local_user: user, title: "Overlap", entry_type: :diary,
                       start_date: Date.new(2026, 9, 10), end_date: Date.new(2026, 9, 15))
    reversed = Note.new(local_user: user, title: "Bad", entry_type: :diary,
                        start_date: Date.new(2026, 9, 13), end_date: Date.new(2026, 9, 7))

    assert_predicate overlap, :valid?
    assert_not reversed.valid?
  end

  test "diary rejects an exact range duplicate for the same user" do
    user = LocalUser.create!(core_user_id: "duplicate-owner")
    attrs = { local_user: user, title: "Day", entry_type: :diary,
              start_date: Date.new(2026, 9, 7), end_date: Date.new(2026, 9, 7) }
    Note.create!(attrs)
    duplicate = Note.new(attrs)

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:start_date], "has already been taken for this range"
  end

  test "diary allows a range that matches a regular note" do
    user = LocalUser.create!(core_user_id: "cross-type-owner")
    dates = { start_date: Date.new(2026, 9, 7), end_date: Date.new(2026, 9, 7) }
    Note.create!(local_user: user, title: "Regular", entry_type: :regular, **dates)
    diary = Note.new(local_user: user, title: "Diary", entry_type: :diary, **dates)

    assert_predicate diary, :valid?
  end
end
