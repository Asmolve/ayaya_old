require "test_helper"

class RuleClassifierTest < ActiveSupport::TestCase
  test "permanent exclusion wins over every other assignment" do
    result = Telegram::RuleClassifier.new.classify(
      dialog: { peer_id: "100", peer_kind: "channel", username: "work" },
      assignments: [ { source: "manual", folder_id: "work" }, { source: "excluded" } ],
      rules: [ { priority: 1, condition: { "username" => "work" }, folder_id: "projects" } ]
    )

    assert_equal :excluded, result.status
    assert_nil result.folder_id
  end

  test "equal priority matching rules become a conflict deterministically" do
    result = Telegram::RuleClassifier.new.classify(
      dialog: { peer_id: "100", peer_kind: "channel", username: "work" },
      assignments: [],
      rules: [
        { id: "b", priority: 3, condition: { "username" => "work" }, folder_id: "projects" },
        { id: "a", priority: 3, condition: { "username" => "work" }, folder_id: "work" }
      ]
    )

    assert_equal :conflict, result.status
    assert_equal %w[a b], result.matched_rule_ids
  end
end
