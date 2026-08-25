module Telegram
  class Organizer
    BASE_CATEGORY_TITLES = [ "People", "Work", "Projects", "Family", "Groups", "Channels", "Bots", "Important", "Unread", "Other" ].freeze
    BASE_CATEGORIES = {
      "user" => "People",
      "group" => "Groups",
      "supergroup" => "Groups",
      "channel" => "Channels",
      "bot" => "Bots"
    }.freeze

    def initialize(account:)
      @account = account
      @classifier = RuleClassifier.new
    end

    def call(dialogs:)
      dialogs.each do |dialog|
        organize(dialog.deep_stringify_keys)
      end
    end

    def self.base_categories = BASE_CATEGORY_TITLES

    private

    def organize(dialog)
      assignment = @account.assignments.find_or_initialize_by(peer_kind: dialog.fetch("peer_kind"), peer_id: dialog.fetch("peer_id"))
      return if assignment.persisted? && assignment.locked?

      result = @classifier.classify(dialog:, assignments: assignments_for(dialog), rules: rules)
      category = result.folder_id ? nil : BASE_CATEGORIES.fetch(dialog.fetch("peer_kind"), "Other")
      folder = result.folder_id || folder_for(category)
      proposal = propose_folder(category) unless folder || category.nil?
      assignment.update!(
        folder: folder,
        source: "proposal",
        locked: false,
        confidence: result.confidence,
        explanation: {
          "classification" => result.status.to_s,
          "category" => category,
          "proposed_folder_title" => proposal&.title,
          "folder_proposal_id" => proposal&.proposal_id,
          "used_features" => result.explanation,
          "matched_rule_ids" => result.matched_rule_ids
        }.compact
      )
    end

    def assignments_for(dialog)
      @account.assignments.where(peer_kind: dialog.fetch("peer_kind"), peer_id: dialog.fetch("peer_id")).where.not(source: "proposal").map do |assignment|
        { source: assignment.source, folder_id: assignment.folder_id }
      end
    end

    def rules
      @account.rules.where(enabled: true).map do |rule|
        { id: rule.rule_id, priority: rule.priority, condition: rule.condition_json, folder_id: rule.target_folder_id, enabled: rule.enabled? }
      end
    end

    def folder_for(category)
      return unless category

      @account.folders.find_by(title: category)
    end

    def propose_folder(category)
      @account.folder_proposals.find_or_create_by!(category:) do |proposal|
        proposal.proposal_id = SecureRandom.uuid
        proposal.title = category
        proposal.status = "proposed"
        proposal.explanation = { "origin" => "base_category", "app_owned_after_confirmed_refetch" => true }
      end
    end
  end
end
