require "test_helper"

class NotesControllerTest < ActionDispatch::IntegrationTest
  def ayaya_headers(core_user_id: "1", email: "user@example.test")
    {
      "X-Ayaya-User-Id" => core_user_id,
      "X-Ayaya-User-Email" => email,
      "X-Ayaya-User-Display-Name" => "User #{core_user_id}",
      "X-Ayaya-User-Role" => "user",
      "X-Ayaya-Module-Key" => "notes"
    }
  end

  test "shows empty state and new note link for a user without notes" do
    get "/m/notes", headers: ayaya_headers(core_user_id: "1")

    assert_response :success
    assert_includes response.body, "No notes yet."
    assert_includes response.body, "New note"
  end

  test "lists only current user's notes" do
    owner = LocalUser.create!(core_user_id: "1")
    other = LocalUser.create!(core_user_id: "2")
    Note.create!(local_user: owner, title: "Mine", body: "Visible")
    Note.create!(local_user: other, title: "Other", body: "Hidden")

    get "/m/notes", headers: ayaya_headers(core_user_id: "1")

    assert_response :success
    assert_includes response.body, "Mine"
    assert_not_includes response.body, "Other"
  end

  test "creates note owned by current local user" do
    assert_difference("Note.count", 1) do
      post "/m/notes/notes", params: { note: { title: "New note", body: "Body" } }, headers: ayaya_headers(core_user_id: "1")
    end

    note = Note.last
    assert_equal "1", note.local_user.core_user_id
    assert_redirected_to "/m/notes/notes/#{note.id}"
  end

  test "does not show another user's note" do
    other = LocalUser.create!(core_user_id: "2")
    note = Note.create!(local_user: other, title: "Other", body: "Hidden")

    get "/m/notes/notes/#{note.id}", headers: ayaya_headers(core_user_id: "1")

    assert_response :not_found
  end

  test "updates only own note" do
    owner = LocalUser.create!(core_user_id: "1")
    note = Note.create!(local_user: owner, title: "Old", body: "Body")

    patch "/m/notes/notes/#{note.id}", params: { note: { title: "New", body: "Updated" } }, headers: ayaya_headers(core_user_id: "1")

    assert_redirected_to "/m/notes/notes/#{note.id}"
    assert_equal "New", note.reload.title
  end

  test "does not delete another user's note" do
    other = LocalUser.create!(core_user_id: "2")
    note = Note.create!(local_user: other, title: "Other", body: "Hidden")

    assert_no_difference("Note.count") do
      delete "/m/notes/notes/#{note.id}", headers: ayaya_headers(core_user_id: "1")
    end

    assert_response :not_found
  end
end
