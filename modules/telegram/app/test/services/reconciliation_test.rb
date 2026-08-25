require "test_helper"

class ReconciliationTest < ActiveSupport::TestCase
  test "confirms an unknown outcome by refetching instead of replaying the Telegram mutation" do
    client = Telegram::TestClient.new(remote_state: { "folders" => [ { "id" => 7, "title" => "Work" } ] })
    step = Struct.new(:expected_postcondition, :status, keyword_init: true).new(expected_postcondition: { "folders" => [ { "id" => 7, "title" => "Work" } ] }, status: "outcome_unknown")

    result = Telegram::Reconciler.new(client: client).reconcile(step)

    assert_equal :confirmed, result
    assert_empty client.mutations
  end
end
