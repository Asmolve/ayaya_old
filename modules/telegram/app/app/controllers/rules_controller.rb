class RulesController < ApplicationController
  include AyayaIdentity

  def create
    account = current_module_user.telegram_account
    return redirect_to telegram_root_path, alert: "Connect Telegram first." unless account

    account.rules.create!(rule_params)
    redirect_to telegram_root_path, notice: "Rule saved."
  rescue ActiveRecord::RecordInvalid => error
    redirect_to telegram_root_path, alert: error.record.errors.full_messages.to_sentence
  end

  def update
    current_module_user.telegram_account.rules.find(params[:id]).update!(rule_params)
    redirect_to telegram_root_path, notice: "Rule updated."
  rescue ActiveRecord::RecordNotFound
    head :not_found
  rescue ActiveRecord::RecordInvalid => error
    redirect_to telegram_root_path, alert: error.record.errors.full_messages.to_sentence
  end

  private

  def rule_params
    attributes = params.require(:rule).permit(:rule_id, :version, :priority, :target_folder_id, :enabled, :explanation, condition_json: {}).to_h
    attributes["condition_json"] = normalized_conditions(attributes["condition_json"]) if attributes.key?("condition_json")
    attributes
  end

  def normalized_conditions(conditions)
    conditions.to_h.stringify_keys.each_with_object({}) do |(key, value), normalized|
      value = value.strip if value.is_a?(String)
      next if value.blank?

      normalized[key] = %w[keywords manual_list].include?(key) ? value.to_s.split(/[\n,]/).map(&:strip).reject(&:blank?) : value
    end
  end
end
