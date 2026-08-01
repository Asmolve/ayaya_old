require "test_helper"

class NoteTest < ActiveSupport::TestCase
  test "requires owner and title" do
    note = Note.new(body: "Body")

    assert_not note.valid?
    assert_includes note.errors[:local_user], "must exist"
    assert_includes note.errors[:title], "can't be blank"
  end
end
