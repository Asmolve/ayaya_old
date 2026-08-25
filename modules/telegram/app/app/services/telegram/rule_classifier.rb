module Telegram
  class RuleClassifier
    Result = Data.define(:status, :folder_id, :matched_rule_ids, :explanation, :confidence)

    def classify(dialog:, assignments:, rules:)
      dialog = dialog.deep_stringify_keys
      excluded = assignments.find { |assignment| assignment[:source].to_s == "excluded" }
      return Result.new(:excluded, nil, [], [ "permanent_exclusion" ], 1.0) if excluded

      manual = assignments.find { |assignment| assignment[:source].to_s == "manual" }
      return Result.new(:assigned, manual[:folder_id], [], [ "manual_assignment" ], 1.0) if manual

      matches = rules.select { |rule| rule.fetch(:enabled, rule.fetch("enabled", true)) && matches?(rule[:condition] || rule["condition"] || {}, dialog) }
      return base_category(dialog) if matches.empty?

      best_rank, best_priority = matches.map { |rule| [ specificity(rule[:condition] || rule["condition"] || {}), rule[:priority].to_i ] }.min
      best = matches.select { |rule| specificity(rule[:condition] || rule["condition"] || {}) == best_rank && rule[:priority].to_i == best_priority }.sort_by { |rule| rule[:id].to_s }
      return Result.new(:conflict, nil, best.map { |rule| rule[:id].to_s }, [ "equal_priority_rules" ], 0.0) if best.map { |rule| rule[:folder_id] }.uniq.many?

      Result.new(:assigned, best.first[:folder_id], best.map { |rule| rule[:id].to_s }, [ "rule", *condition_keys(best.first[:condition] || best.first["condition"] || {}) ], confidence_for(best_rank))
    end

    private

    def matches?(condition, dialog)
      condition.deep_stringify_keys.all? do |key, value|
        case key
        when "peer_id", "username", "title", "peer_kind", "language" then dialog[key].to_s == value.to_s
        when "unread" then ActiveModel::Type::Boolean.new.cast(dialog[key]) == ActiveModel::Type::Boolean.new.cast(value)
        when "manual_list" then Array(value).map(&:to_s).include?(dialog.fetch("peer_id").to_s)
        when "keywords" then Array(value).any? { |word| [ dialog["title"], dialog["username"] ].compact.join(" ").downcase.include?(word.to_s.downcase) }
        when "regex" then SafeRegex.match?(value, [ dialog["title"], dialog["username"] ].compact.join(" "))
        else false
        end
      rescue RegexpError
        false
      end
    end

    def specificity(condition)
      keys = condition_keys(condition)
      return 1 if (keys & %w[peer_id manual_list]).any?
      return 2 if keys.include?("username")
      return 3 if (keys & %w[title regex]).any?
      return 4 if keys.include?("peer_kind")
      return 5 if keys.include?("keywords")

      6
    end

    def condition_keys(condition)
      condition.to_h.stringify_keys.keys.sort
    end

    def confidence_for(rank)
      { 1 => 0.98, 2 => 0.92, 3 => 0.88, 4 => 0.65, 5 => 0.60, 6 => 0.55 }.fetch(rank)
    end

    def base_category(dialog)
      category = Organizer::BASE_CATEGORIES.fetch(dialog["peer_kind"].to_s, "Other")
      Result.new(:proposed, nil, [], [ "base_category", category ], 0.65)
    end
  end
end
