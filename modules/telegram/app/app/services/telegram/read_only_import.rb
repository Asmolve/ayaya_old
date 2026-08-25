module Telegram
  class ReadOnlyImport
    def initialize(account:, client:)
      @account = account
      @client = client
    end

    def call
      state, complete, seen_dialogs = import_all_pages
      limits = DynamicLimits.from_app_config(state.fetch("app_config", {}))
      canonical = CanonicalSnapshot.build(
        account_id: @account.telegram_account_id,
        folder_order: Array(state["folder_order"]),
        filters: state.fetch("folders", []).map { |folder| FilterState.normalize(folder) },
        dialogs: state.fetch("dialogs", []).map { |dialog| dialog.slice("peer_kind", "peer_id", "input_peer_ref", "access_hash", "title", "username", "avatar_url", "metadata_hash") },
        app_config: state.fetch("app_config", {}),
        limits: limits.to_h,
        rule_versions: @account.rules.order(:rule_id, :version).pluck(:rule_id, :version),
        normalization_version: FilterState::NORMALIZATION_VERSION
      )

      ApplicationRecord.transaction do
        state.fetch("dialogs", []).each do |dialog|
          attributes = dialog.slice("peer_kind", "peer_id", "input_peer_ref", "access_hash", "title", "username", "avatar_url", "metadata_hash").merge("last_seen_at" => Time.current, "stale_at" => nil)
          @account.dialogs.upsert(attributes.merge("telegram_account_id" => @account.id), unique_by: %i[telegram_account_id peer_kind peer_id])
        end
        if complete
          @account.dialogs.find_each do |dialog|
            dialog.update!(stale_at: Time.current) unless seen_dialogs.include?([ dialog.peer_kind, dialog.peer_id ])
          end
        end
        state.fetch("folders", []).each do |folder|
          existing = @account.folders.find_by(telegram_folder_id: folder.fetch("telegram_folder_id"))
          incoming = folder.deep_stringify_keys
          incoming_fingerprint = incoming["remote_fingerprint"].presence || Ownership.fingerprint_for(incoming)
          managed = !!(existing && Ownership.mutable?(existing.attributes.merge("remote_fingerprint" => incoming_fingerprint), account_id: @account.telegram_account_id))
          attributes = incoming.slice("telegram_folder_id", "title", "emoji", "mode").merge(
            "remote_fingerprint" => incoming_fingerprint,
            "remote_state" => FilterState.normalize(incoming),
            "managed_by_app" => managed,
            "ownership_state" => managed ? "confirmed" : "foreign",
            "ownership_record" => managed ? existing.ownership_record : {}
          )
          @account.folders.upsert(attributes.merge("telegram_account_id" => @account.id), unique_by: %i[telegram_account_id telegram_folder_id])
        end
        Organizer.new(account: @account).call(dialogs: state.fetch("dialogs", []))
        @account.snapshots.create_or_find_by!(snapshot_id: canonical.source_hash) do |snapshot|
          snapshot.kind = "import"
          snapshot.canonical_version = CanonicalSnapshot::VERSION
          snapshot.source_hash = canonical.source_hash
          snapshot.payload = EncryptedPayload.encrypt(canonical.payload)
          snapshot.retention_until = 30.days.from_now
        end
        @account.update!(last_seen_at: Time.current)
      end
      @account.update_persisted_limits!(limits)
      limits
    end

    private

    def import_all_pages
      cursor = nil
      seen_cursors = Set.new
      dialogs = {}
      folders = {}
      app_config = {}
      folder_order = []
      seen_dialogs = Set.new
      complete = false

      10_000.times do
        response = JsonBoundary.normalize(@client.import_state(cursor:))
        page = JsonBoundary.normalize(response.fetch("state"))
        page.fetch("dialogs", []).each do |dialog|
          normalized = JsonBoundary.normalize(dialog)
          key = [ normalized.fetch("peer_kind"), normalized.fetch("peer_id") ]
          dialogs[key] = normalized
          seen_dialogs << key
        end
        page.fetch("folders", []).each do |folder|
          normalized = JsonBoundary.normalize(folder)
          folders[normalized.fetch("telegram_folder_id").to_s] = normalized
        end
        app_config = page.fetch("app_config", app_config)
        folder_order = Array(page["folder_order"]) if page.key?("folder_order")
        complete = response["complete"] == true
        break if complete

        cursor = response["cursor"].presence
        raise ClientResponseError, "MTProto import ended without completion" unless cursor
        raise ClientResponseError, "MTProto import cursor made no progress" if seen_cursors.include?(cursor)

        seen_cursors << cursor
      end
      raise ClientResponseError, "MTProto import exceeded the page limit" unless complete

      [ { "dialogs" => dialogs.values, "folders" => folders.values, "folder_order" => folder_order, "app_config" => app_config }, complete, seen_dialogs ]
    end
  end
end
