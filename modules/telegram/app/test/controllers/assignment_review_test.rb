require "test_helper"

class AssignmentReviewTest < ActionDispatch::IntegrationTest
  test "each proposal can be accepted, changed, skipped, or blocked without affecting another proposal" do
    user = ModuleUser.create!(core_user_id: "assignment-review")
    account = TelegramAccount.create!(module_user: user, telegram_account_id: "assignment-review")
    work = account.folders.create!(telegram_folder_id: 1, title: "Work", ownership_state: "proposed")
    projects = account.folders.create!(telegram_folder_id: 2, title: "Projects", ownership_state: "proposed")
    accepted = proposal(account, "accepted")
    changed = proposal(account, "changed")
    skipped = proposal(account, "skipped")
    blocked = proposal(account, "blocked")

    review(accepted, "accept", folder_id: work.id, user_id: user.core_user_id)
    assert_equal [ work.id, "manual", true ], accepted.reload.attributes.values_at("folder_id", "source", "locked")

    review(changed, "change", folder_id: projects.id, user_id: user.core_user_id)
    assert_equal [ projects.id, "manual", true ], changed.reload.attributes.values_at("folder_id", "source", "locked")

    review(skipped, "skip", user_id: user.core_user_id)
    assert_equal [ nil, "proposal", false ], skipped.reload.attributes.values_at("folder_id", "source", "locked")

    review(blocked, "block", user_id: user.core_user_id)
    assert_equal [ nil, "excluded", true ], blocked.reload.attributes.values_at("folder_id", "source", "locked")
  end

  private

  def proposal(account, peer_id)
    account.assignments.create!(peer_kind: "channel", peer_id:, source: "proposal", locked: false, confidence: 0.65, explanation: {})
  end

  def review(assignment, action, folder_id: nil, user_id:)
    get "/m/telegram", headers: ayaya_headers(user_id:)
    token = response.body.match(/meta name="csrf-token" content="([^"]+)"/)[1]
    patch "/m/telegram/assignments/#{assignment.id}/review", params: { review_action: action, folder_id: folder_id }, headers: ayaya_headers(user_id:).merge("X-CSRF-Token" => token)
    assert_response :redirect
  end
end
