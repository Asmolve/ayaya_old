class AssignmentsController < ApplicationController
  include AyayaIdentity

  def create
    account = current_module_user.telegram_account
    return redirect_to telegram_root_path, alert: "Connect Telegram first." unless account

    assignment = account.assignments.find_or_initialize_by(peer_kind: assignment_params.fetch("peer_kind"), peer_id: assignment_params.fetch("peer_id"))
    assignment.update!(assignment_params.merge(source: assignment_params["folder_id"].present? ? "manual" : "excluded", locked: true))
    redirect_to telegram_root_path, notice: "Manual assignment saved."
  rescue ActiveRecord::RecordInvalid => error
    redirect_to telegram_root_path, alert: error.record.errors.full_messages.to_sentence
  end

  def update
    current_module_user.telegram_account.assignments.find(params[:id]).update!(assignment_params.merge(source: assignment_params["folder_id"].present? ? "manual" : "excluded", locked: true))
    redirect_to telegram_root_path, notice: "Manual assignment updated."
  rescue ActiveRecord::RecordNotFound
    head :not_found
  rescue ActiveRecord::RecordInvalid => error
    redirect_to telegram_root_path, alert: error.record.errors.full_messages.to_sentence
  end

  def bulk
    account = current_module_user.telegram_account
    assignments = account.assignments.where(id: Array(params[:assignment_ids]), source: "proposal")
    case params[:bulk_action]
    when "accept"
      assignments.update_all(folder_id: bulk_folder_id!, source: "manual", locked: true, updated_at: Time.current)
    when "exclude"
      assignments.update_all(folder_id: nil, source: "excluded", locked: true, updated_at: Time.current)
    when "skip"
      assignments.update_all(locked: false, updated_at: Time.current)
    else
      raise ActionController::BadRequest, "Unsupported bulk action"
    end
    redirect_to telegram_root_path, notice: "#{assignments.count} proposals updated."
  rescue ActiveRecord::RecordNotFound, ActionController::BadRequest => error
    redirect_to telegram_root_path, alert: error.message
  end

  def review
    assignment = current_module_user.telegram_account.assignments.find(params[:id])
    case params.require(:review_action)
    when "accept", "change"
      assignment.update!(folder: review_folder!, source: "manual", locked: true)
    when "skip"
      assignment.update!(source: "proposal", locked: false)
    when "block"
      assignment.update!(folder: nil, source: "excluded", locked: true)
    else
      raise ActionController::BadRequest, "Unsupported proposal action"
    end
    redirect_to telegram_root_path, notice: "Proposal updated."
  rescue ActiveRecord::RecordNotFound, ActionController::BadRequest => error
    redirect_to telegram_root_path, alert: error.message
  rescue ActiveRecord::RecordInvalid => error
    redirect_to telegram_root_path, alert: error.record.errors.full_messages.to_sentence
  end

  private

  def assignment_params
    params.require(:assignment).permit(:peer_kind, :peer_id, :folder_id, :confidence, :locked, explanation: {}).to_h
  end

  def bulk_folder_id!
    current_module_user.telegram_account.folders.find(params.require(:folder_id)).id
  end

  def review_folder!
    current_module_user.telegram_account.folders.find(params.require(:folder_id))
  end
end
