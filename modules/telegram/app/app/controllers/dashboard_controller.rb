class DashboardController < ApplicationController
  include AyayaIdentity

  def show
    @account = current_module_user.telegram_account
    @folders = @account ? @account.folders.order(:title) : []
    @folder_proposals = @account ? @account.folder_proposals.order(:category) : []
    @operations = @account ? @account.operations.order(created_at: :desc).limit(10) : []
    @proposal_query = params[:q].to_s.strip
    @proposal_filter = params.fetch(:proposal_filter, "all")
    @dialogs = filtered_dialogs
    @rules = @account ? @account.rules.order(priority: :asc, created_at: :asc) : []
    @assignments = filtered_proposals
    @dialogs_by_peer = @account ? @account.dialogs.index_by { |dialog| [ dialog.peer_kind, dialog.peer_id ] } : {}
    @limits = @account ? @account.persisted_limits : {}
    @base_categories = Telegram::Organizer.base_categories
    @folder_usage = folder_usage
    @last_sync_at = @account ? (@account.dialogs.maximum(:last_seen_at) || @account.last_seen_at) : nil
    @current_folder_titles_by_peer = current_folder_titles_by_peer
  end

  private

  def filtered_dialogs
    return [] unless @account

    scope = @account.dialogs.order(:title)
    scope = scope.where("title ILIKE :query OR username ILIKE :query OR peer_id ILIKE :query", query: "%#{ActiveRecord::Base.sanitize_sql_like(@proposal_query)}%") if @proposal_query.present?
    scope.limit(100)
  end

  def filtered_proposals
    return [] unless @account

    matching_peers = @dialogs.map { |dialog| [ dialog.peer_kind, dialog.peer_id ] }.to_set
    @account.assignments.where(source: "proposal").includes(:folder).order(updated_at: :desc).to_a.select do |assignment|
      next false if @proposal_query.present? && !matching_peers.include?([ assignment.peer_kind, assignment.peer_id ])

      classification = assignment.explanation["classification"]
      case @proposal_filter
      when "conflicts" then classification == "conflicted"
      when "uncertain" then assignment.confidence.to_f < 0.75
      when "ready" then classification != "conflicted" && assignment.confidence.to_f >= 0.75
      else true
      end
    end.first(100)
  end

  def current_folder_titles_by_peer
    return {} unless @account

    @account.folders.each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |folder, titles|
      Array(folder.remote_state["include_peers"]).each do |peer|
        key = [ peer["kind"].to_s, peer["id"].to_s ]
        titles[key] << folder.title
      end
    end
  end

  def folder_usage
    return {} unless @account

    assigned_counts = @account.assignments.where.not(folder_id: nil).group(:folder_id).count
    @account.folders.each_with_object({}) do |folder, usage|
      remote_count = Array(folder.remote_state["include_peers"]).length
      usage[folder.id] = [ remote_count, assigned_counts.fetch(folder.id, 0) ].max
    end
  end
end
