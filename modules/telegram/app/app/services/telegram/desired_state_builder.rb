module Telegram
  class DesiredStateBuilder
    def initialize(account:, state:)
      @account = account
      @state = state.deep_stringify_keys
      @folders_by_id = account.folders.index_by { |folder| folder.telegram_folder_id.to_s }
    end

    def build
      current_folders = @state.fetch("folders", []).map { |folder| FilterState.normalize(folder) }
      desired_folders = current_folders.map(&:deep_dup)
      desired_by_id = desired_folders.index_by { |folder| folder.fetch("telegram_folder_id").to_s }

      app_folders.each do |folder|
        unless desired_by_id.key?(folder.telegram_folder_id.to_s)
          desired = desired_folder_for(folder, {})
          desired_folders << desired
          desired_by_id[folder.telegram_folder_id.to_s] = desired
        end
        desired_by_id[folder.telegram_folder_id.to_s].replace(desired_folder_for(folder, desired_by_id.fetch(folder.telegram_folder_id.to_s)))
      end

      members_by_folder = Hash.new { |hash, key| hash[key] = [] }
      active_dialogs.each do |dialog|
        folder = folder_for(dialog)
        next unless folder

        members_by_folder[folder.telegram_folder_id] << dialog.input_peer_ref.deep_stringify_keys
      end

      app_folders.each do |folder|
        desired = desired_by_id.fetch(folder.telegram_folder_id.to_s)
        desired["include_peers"] = members_by_folder.fetch(folder.telegram_folder_id, []).uniq { |peer| FilterState.peer_key(peer) }.sort_by { |peer| FilterState.peer_key(peer) }
      end

      {
        "folders" => desired_folders.sort_by { |folder| folder.fetch("telegram_folder_id").to_i },
        "folder_order" => desired_order(current_folders),
        "policies" => {
          "accepted_assignment_sources" => %w[manual excluded],
          "enabled_rule_versions" => @account.rules.where(enabled: true).order(:rule_id, :version).pluck(:rule_id, :version),
          "stale_dialogs_excluded" => true
        }
      }
    end

    private

    def app_folders
      @app_folders ||= @account.folders.where("managed_by_app = ? OR ownership_state IN (?)", true, %w[proposed confirmed]).order(:local_revision, :telegram_folder_id).to_a
    end

    def active_dialogs
      @account.dialogs.where(stale_at: nil).order(:peer_kind, :peer_id)
    end

    def desired_folder_for(folder, remote)
      FilterState.normalize(remote).merge(
        "telegram_folder_id" => folder.telegram_folder_id,
        "title" => folder.title,
        "emoji" => folder.emoji,
        "mode" => folder.mode,
        "managed_by_app" => true,
        "ownership_record" => folder.ownership_record,
        "remote_fingerprint" => remote["remote_fingerprint"] || folder.remote_fingerprint
      )
    end

    def folder_for(dialog)
      assignment = accepted_assignments[[ dialog.peer_kind, dialog.peer_id ]]
      return nil if assignment&.source == "excluded"
      return assignment.folder if assignment&.folder

      result = classifier.classify(dialog: dialog.attributes, assignments: [], rules: rule_payloads)
      return unless result.status == :assigned

      @folders_by_id.values.find { |folder| folder.id == result.folder_id }
    end

    def accepted_assignments
      @accepted_assignments ||= @account.assignments.where(locked: true, source: %w[manual excluded]).includes(:folder).index_by { |assignment| [ assignment.peer_kind, assignment.peer_id ] }
    end

    def rule_payloads
      @rule_payloads ||= @account.rules.where(enabled: true).order(:priority, :rule_id, :version).map do |rule|
        { id: rule.rule_id, priority: rule.priority, condition: rule.condition_json, folder_id: rule.target_folder_id, enabled: true }
      end
    end

    def classifier
      @classifier ||= RuleClassifier.new
    end

    def desired_order(current_folders)
      current_ids = Array(@state["folder_order"]).presence || current_folders.map { |folder| folder.fetch("telegram_folder_id") }
      anchored_ids = current_ids.map(&:to_i)
      app_folders_by_id = app_folders.index_by(&:telegram_folder_id)
      anchored_ids.slice_when { |left, right| app_folders_by_id.key?(left) != app_folders_by_id.key?(right) }.flat_map do |segment|
        if app_folders_by_id.key?(segment.first)
          segment.sort_by { |id| [ app_folders_by_id.fetch(id).local_revision, id ] }
        else
          segment
        end
      end + app_folders_by_id.keys.reject { |id| anchored_ids.include?(id) }
    end
  end
end
