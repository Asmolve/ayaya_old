require "test_helper"
require "net/http"

class TaskSixReviewTest < ActiveSupport::TestCase
  test "imports every cursor page and marks dialogs absent from a completed import stale" do
    account = writable_account("paged")
    stale = Dialog.create!(telegram_account: account, peer_kind: "user", peer_id: "old", title: "Old", metadata_hash: "old")
    client = PagedImportClient.new(
      [
        { "dialogs" => [ dialog("1", "One") ], "folders" => [], "app_config" => full_limits },
        { "dialogs" => [ dialog("2", "Two") ], "folders" => [], "app_config" => full_limits }
      ]
    )

    Telegram::ReadOnlyImport.new(account: account, client: client).call

    assert_equal %w[1 2 old], account.dialogs.order(:peer_id).pluck(:peer_id)
    assert_predicate stale.reload, :stale_at?
    assert_equal [ nil, "cursor-1" ], client.cursors
  end

  test "creates editable proposals with classification confidence and factual explanation" do
    account = writable_account("organizer")
    client = Telegram::TestClient.new(remote_state: {
      "dialogs" => [ dialog("bot", "Build Bot", peer_kind: "bot") ],
      "folders" => [],
      "app_config" => full_limits
    })

    Telegram::ReadOnlyImport.new(account: account, client: client).call

    proposal = account.assignments.find_by(peer_kind: "bot", peer_id: "bot")
    assert_not_nil proposal
    assert_equal "proposal", proposal.source
    assert_equal "Bots", proposal.explanation.fetch("category")
    assert_in_delta 0.65, proposal.confidence, 0.001
    refute_predicate proposal, :locked?
  end

  test "persists retained operation and snapshot data as encrypted redacted envelopes" do
    account = writable_account("encrypted")
    state = { "folders" => [], "dialogs" => [], "app_config" => full_limits, "message" => "private" }
    client = Telegram::TestClient.new(remote_state: state)

    operation = Telegram::OperationFactory.new(account: account, client: client).dry_run
    snapshot = operation.before_snapshot

    assert_equal 2, operation.plan["version"]
    assert_equal 2, snapshot.payload["version"]
    refute_includes operation.plan.to_json, "Telegram"
    refute_includes snapshot.payload.to_json, "private"
    assert_equal "[REDACTED]", snapshot.payload_data.fetch("state").fetch("message")
  end

  test "rejects rollback for a successful operation that is not the latest one" do
    account = writable_account("rollback")
    state = { "folders" => [], "app_config" => full_limits }
    first = completed_operation(account, "first", state)
    completed_operation(account, "second", state)

    assert_raises(Telegram::PreflightConflict) do
      Telegram::OperationFactory.new(account: account, client: Telegram::TestClient.new(remote_state: state)).rollback(first)
    end
  end

  test "revalidates every step expected postcondition before dispatch" do
    account = writable_account("limits")
    current = { "folders" => [], "app_config" => full_limits }
    operation = encrypted_operation(account, "limits", current)
    step = operation.operation_steps.create!(
      telegram_account: account,
      step_id: "over-limit",
      request_fingerprint: "request",
      precondition_fingerprint: Telegram::CanonicalSnapshot.build(state: current).source_hash,
      expected_postcondition: current.merge("folders" => Array.new(11) { |index| { "telegram_folder_id" => index, "title" => "Folder #{index}" } })
    )
    client = Telegram::TestClient.new(remote_state: current)

    assert_raises(ArgumentError) { Telegram::OperationExecutor.new(operation: operation, client: client, confirmed: true).call }
    assert_equal "failed", step.reload.status
    assert_empty client.mutations
  end

  test "private JSON transport sends only an opaque session handle and normalizes import responses" do
    account = writable_account("transport")
    handle = "opaque-session-handle-v1:8YVWZYlObsaHHjcQIrpCBYXZgzx0R0Bq"
    account.update!(encrypted_session: Telegram::EncryptedSecret.encrypt(handle, key_provider: Telegram::KeyProvider.from_environment))
    http = RecordingHttp.new('{"state":{"dialogs":[],"folders":[],"app_config":{}},"cursor":null,"complete":true}')

    response = Telegram::MtprotoClient.new(endpoint: "http://telegram_mtproto:8081", account: account, http: http).import_state

    payload = JSON.parse(http.last_request.body)
    assert_equal handle, payload["session_handle"]
    refute payload.key?("session")
    assert_equal [], response.fetch("state").fetch("dialogs")
    assert_equal true, response.fetch("complete")
  end

  test "keeps a safe QR image available for display without retaining its login URL" do
    account = TelegramAccount.create!(module_user: ModuleUser.create!(core_user_id: "qr"), telegram_account_id: "pending")
    client = Telegram::TestClient.new(auth_result: { "state" => "awaiting_qr", "challenge_id" => "qr-1", "qr_data_uri" => "data:image/png;base64,cXVhbGlmaWVk" })

    Telegram::AuthenticationFlow.new(account: account, client: client).start_qr

    assert_equal "data:image/png;base64,cXVhbGlmaWVk", account.reload.auth_challenge["qr_data_uri"]
    refute account.auth_challenge.key?("qr_url")
  end

  test "restart recovery reconciles dispatched steps instead of replaying a write" do
    account = writable_account("recovery")
    state = { "folders" => [], "app_config" => full_limits }
    operation = encrypted_operation(account, "recovery", state)
    operation.update!(status: "reconciling")
    step = operation.operation_steps.create!(telegram_account: account, step_id: "sent", status: "dispatched", request_fingerprint: "r", precondition_fingerprint: "p", expected_postcondition: state)
    client = Telegram::TestClient.new(remote_state: state)

    Telegram::OperationRecovery.reconcile!(account: account, client: client)

    assert_equal "confirmed", step.reload.status
    assert_equal "completed", operation.reload.status
    assert_empty client.mutations
  end

  test "restart recovery resumes only the remaining step after its precondition matches" do
    account = writable_account("partial-recovery")
    before = { "folders" => [], "app_config" => full_limits }
    after_first = before.merge("folders" => [ { "telegram_folder_id" => 1, "title" => "Work" } ])
    after_second = after_first.merge("folder_order" => [ 1 ])
    operation = encrypted_operation(account, "partial-recovery", before)
    operation.update!(status: "reconciling")
    operation.operation_steps.create!(
      telegram_account: account,
      sequence: 0,
      step_id: "create-work",
      status: "dispatched",
      request_fingerprint: "create-work",
      precondition_fingerprint: Telegram::CanonicalSnapshot.build(state: before).source_hash,
      expected_postcondition: after_first
    )
    operation.operation_steps.create!(
      telegram_account: account,
      sequence: 1,
      step_id: "order-work",
      rpc: "update_dialog_filters_order",
      request_fingerprint: "order-work",
      precondition_fingerprint: Telegram::CanonicalSnapshot.build(state: after_first).source_hash,
      expected_postcondition: after_second
    )
    client = Telegram::TestClient.new(remote_state: after_first)

    Telegram::OperationRecovery.reconcile!(account: account, client: client)

    assert_equal "confirmed", operation.operation_steps.find_by!(step_id: "create-work").reload.status
    assert_equal "confirmed", operation.operation_steps.find_by!(step_id: "order-work").reload.status
    assert_equal "completed", operation.reload.status
    assert_equal [ "update_dialog_filters_order" ], client.mutations.pluck("rpc")
  end

  test "restart recovery conflicts instead of dispatching a remaining step with a stale precondition" do
    account = writable_account("partial-recovery-conflict")
    before = { "folders" => [], "app_config" => full_limits }
    expected_after_first = before.merge("folders" => [ { "telegram_folder_id" => 1, "title" => "Work" } ])
    actual_after_first = before.merge("folders" => [ { "telegram_folder_id" => 9, "title" => "Elsewhere" } ])
    operation = encrypted_operation(account, "partial-recovery-conflict", before)
    operation.update!(status: "reconciling")
    operation.operation_steps.create!(
      telegram_account: account,
      sequence: 0,
      step_id: "create-work",
      status: "confirmed",
      request_fingerprint: "create-work",
      precondition_fingerprint: Telegram::CanonicalSnapshot.build(state: before).source_hash,
      expected_postcondition: expected_after_first
    )
    operation.operation_steps.create!(
      telegram_account: account,
      sequence: 1,
      step_id: "order-work",
      rpc: "update_dialog_filters_order",
      request_fingerprint: "order-work",
      precondition_fingerprint: Telegram::CanonicalSnapshot.build(state: expected_after_first).source_hash,
      expected_postcondition: actual_after_first.merge("folder_order" => [ 9 ])
    )
    client = Telegram::TestClient.new(remote_state: actual_after_first)

    Telegram::OperationRecovery.reconcile!(account: account, client: client)

    assert_equal "conflicted", operation.reload.status
    assert_empty client.mutations
  end

  test "restart recovery does not resume later steps while an earlier outcome remains unknown" do
    account = writable_account("partial-recovery-unknown")
    before = { "folders" => [], "app_config" => full_limits }
    after_first = before.merge("folders" => [ { "telegram_folder_id" => 1, "title" => "Work" } ])
    operation = encrypted_operation(account, "partial-recovery-unknown", before)
    operation.update!(status: "reconciling")
    operation.operation_steps.create!(
      telegram_account: account,
      sequence: 0,
      step_id: "create-work",
      status: "dispatched",
      request_fingerprint: "create-work",
      precondition_fingerprint: Telegram::CanonicalSnapshot.build(state: before).source_hash,
      expected_postcondition: after_first
    )
    operation.operation_steps.create!(
      telegram_account: account,
      sequence: 1,
      step_id: "order-work",
      rpc: "update_dialog_filters_order",
      request_fingerprint: "order-work",
      precondition_fingerprint: Telegram::CanonicalSnapshot.build(state: after_first).source_hash,
      expected_postcondition: after_first.merge("folder_order" => [ 1 ])
    )
    client = Telegram::TestClient.new(remote_state: before)

    Telegram::OperationRecovery.reconcile!(account: account, client: client)

    assert_equal "outcome_unknown", operation.operation_steps.find_by!(step_id: "create-work").reload.status
    assert_equal "reconciling", operation.reload.status
    assert_empty client.mutations
  end

  private

  def writable_account(id)
    TelegramAccount.create!(module_user: ModuleUser.create!(core_user_id: id), telegram_account_id: "account-#{id}", read_only: false)
  end

  def dialog(id, title, peer_kind: "channel")
    { "peer_kind" => peer_kind, "peer_id" => id, "input_peer_ref" => { "id" => id }, "title" => title, "metadata_hash" => "hash-#{id}" }
  end

  def full_limits
    {
      "dialog_filters_limit_default" => 10,
      "dialog_filters_chats_limit_default" => 100,
      "dialogs_folder_pinned_limit_default" => 5,
      "dialog_filters_title_length_limit_default" => 12
    }
  end

  def completed_operation(account, id, state)
    operation = encrypted_operation(account, id, state)
    operation.update!(status: "completed", completed_at: Time.current)
    operation
  end

  def encrypted_operation(account, id, state)
    snapshot = account.snapshots.create!(snapshot_id: "before-#{id}", kind: "before_apply", canonical_version: 2, source_hash: id, payload: Telegram::EncryptedPayload.encrypt({ "state" => state }))
    Operation.create!(telegram_account: account, operation_id: id, status: "awaiting_confirmation", before_snapshot: snapshot, plan: Telegram::EncryptedPayload.encrypt({ "preflight_fingerprint" => Telegram::CanonicalSnapshot.build(state: state).source_hash, "folder_count" => 0, "title" => "Telegram", "conflicts" => [] }))
  end

  class PagedImportClient
    attr_reader :cursors

    def initialize(pages)
      @pages = pages
      @cursors = []
    end

    def import_state(cursor: nil)
      @cursors << cursor
      index = cursor ? 1 : 0
      { state: @pages.fetch(index), cursor: index.zero? ? "cursor-1" : nil, complete: index == 1 }
    end
  end

  class RecordingHttp
    attr_reader :last_request

    def initialize(body)
      @body = body
    end

    def start(*)
      yield self
    end

    def request(request)
      @last_request = request
      Response.new(@body)
    end

    class Response < Net::HTTPOK
      def initialize(body)
        super("1.1", "200", "OK")
        @payload = body
      end

      def body = @payload
    end
  end
end
