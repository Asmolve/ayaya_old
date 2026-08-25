require "test_helper"

class RuleTest < ActiveSupport::TestCase
  test "rejects a rule without a meaningful condition" do
    account = TelegramAccount.create!(module_user: ModuleUser.create!(core_user_id: "empty-rule"), telegram_account_id: "empty-rule")
    rule = account.rules.build(rule_id: "empty", version: 1, priority: 1, condition_json: {})

    refute_predicate rule, :valid?
    assert_includes rule.errors[:condition_json], "must include at least one predicate"
  end
end
