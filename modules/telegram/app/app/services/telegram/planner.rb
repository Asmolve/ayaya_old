module Telegram
  class Planner
    def initialize(current_folders:, desired_folders:, account_id: nil, confirmed_folder_ids: nil)
      @current_folders = current_folders
      @desired_folders = desired_folders
      @account_id = account_id
      @confirmed_folder_ids = confirmed_folder_ids&.map(&:to_s)
    end

    def diff
      current = @current_folders.index_by { |folder| identity(folder) }
      desired = @desired_folders.index_by { |folder| identity(folder) }
      creates = desired.keys - current.keys
      deletes = current.keys - desired.keys
      updates = (current.keys & desired.keys).select { |id| canonical(current[id]) != canonical(desired[id]) }
      { "create" => creates.sort.map { |id| desired[id] }, "update" => updates.sort.map { |id| desired[id] }, "delete" => deletes.sort.map { |id| current[id] } }
    end

    def safe_diff
      allowed = { "create" => [], "update" => [], "delete" => [], "conflicts" => [] }
      diff.each do |action, folders|
        folders.each do |folder|
          if action == "create"
            allowed[action] << folder
            next
          end

          current = @current_folders.find { |candidate| identity(candidate) == identity(folder) } || folder
          reason = locally_confirmed?(current) ? Ownership.conflict_reason(current, account_id: @account_id) : "unconfirmed_ownership"
          if reason
            allowed["conflicts"] << { "action" => action, "reason" => reason, "folder" => current.slice("telegram_folder_id", "title", "remote_fingerprint") }
          else
            allowed[action] << folder
          end
        end
      end
      allowed
    end

    def detailed_diff
      current = @current_folders.index_by { |folder| identity(folder) }
      desired = @desired_folders.index_by { |folder| identity(folder) }
      (current.keys & desired.keys).sort.filter_map do |id|
        before = current.fetch(id).deep_stringify_keys
        after = desired.fetch(id).deep_stringify_keys
        fields = %w[title emoji mode flags include_peers exclude_peers pinned_peers].filter_map do |field|
          next if before[field] == after[field]

          [ field, { "from" => before[field], "to" => after[field] } ]
        end.to_h
        include_before = Array(before["include_peers"] || before["include"])
        include_after = Array(after["include_peers"] || after["include"])
        next if fields.empty?

        {
          "telegram_folder_id" => id,
          "fields" => fields,
          "chats_added" => include_after - include_before,
          "chats_removed" => include_before - include_after,
          "order_changed" => include_before != include_after && canonical_peer_set(include_before) == canonical_peer_set(include_after)
        }
      end
    end

    def durable_steps(state:, desired_order:)
      state = state.deep_stringify_keys
      working = state.deep_dup
      steps = []
      safe_diff.slice("create", "update", "delete").each do |action, folders|
        folders.each do |folder|
          next_state = apply_folder_change(working, action, folder)
          steps << {
            "rpc" => "update_dialog_filter",
            "request" => { "action" => action, "folder" => FilterState.canonical(folder) },
            "expected_postcondition" => next_state
          }
          working = next_state
        end
      end

      current_order = Array(working["folder_order"]).presence || working.fetch("folders", []).map { |folder| FilterState.normalize(folder).fetch("telegram_folder_id") }
      if current_order.map(&:to_i) != desired_order.map(&:to_i)
        working = working.merge("folder_order" => desired_order.map(&:to_i))
        steps << {
          "rpc" => "update_dialog_filters_order",
          "request" => { "folder_order" => desired_order.map(&:to_i) },
          "expected_postcondition" => working
        }
      end
      steps
    end

    private

    def canonical(folder) = FilterState.canonical(folder)

    def apply_folder_change(state, action, folder)
      identity_value = identity(folder)
      folders = state.fetch("folders", []).map { |candidate| FilterState.normalize(candidate) }
      case action
      when "create"
        folders << FilterState.canonical(folder)
      when "update"
        folders.map! { |candidate| identity(candidate) == identity_value ? FilterState.canonical(folder) : candidate }
      when "delete"
        folders.reject! { |candidate| identity(candidate) == identity_value }
      end
      state.merge("folders" => folders.sort_by { |candidate| identity(candidate) })
    end

    def canonical_peer_set(peers)
      peers.map { |peer| JSON.generate(peer.deep_stringify_keys.sort.to_h) }.sort
    end

    def identity(folder)
      (folder["telegram_folder_id"] || folder["app_folder_id"] || folder.fetch("title")).to_s
    end

    def locally_confirmed?(folder)
      @confirmed_folder_ids.nil? || @confirmed_folder_ids.include?(identity(folder))
    end
  end
end
