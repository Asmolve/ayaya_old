class OperationsController < ApplicationController
  include AyayaIdentity

  def show
    @operation = scoped_operations.find_by!(operation_id: params[:id])
    render json: { operation_id: @operation.operation_id, status: @operation.status, plan: Telegram::Redactor.call(@operation.plan_data), steps: @operation.operation_steps.order(:created_at).map { |step| step.slice(:step_id, :status, :error_json, :result_fingerprint) } }
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end

  def dry_run
    account = current_module_user.telegram_account
    return redirect_to telegram_root_path, alert: "Connect Telegram first." unless account

    operation = Telegram::OperationFactory.new(account: account, client: Telegram::ClientRegistry.client_for(account)).dry_run
    redirect_to telegram_root_path, notice: "Dry-run #{operation.operation_id} is ready for confirmation."
  rescue Telegram::ClientNotConfigured, Telegram::PreflightConflict, Telegram::ClientResponseError, ArgumentError => error
    redirect_to telegram_root_path, alert: error.message
  end

  def apply
    operation = scoped_operations.find_by!(operation_id: params[:id])
    return redirect_to telegram_root_path, alert: "Read-only mode prevents Telegram changes." if operation.telegram_account.read_only?
    return redirect_to telegram_root_path, alert: "Explicit confirmation is required." unless params[:confirm] == "apply"

    operation.request_execution!
    Telegram::OperationWorker.perform_later(operation.operation_id)
    redirect_to telegram_root_path, notice: "Operation queued for durable execution."
  rescue ActiveRecord::RecordNotFound
    head :not_found
  rescue Telegram::ClientNotConfigured, Telegram::PreflightConflict, Telegram::ClientResponseError, ArgumentError => error
    redirect_to telegram_root_path, alert: error.message
  end

  def cancel
    operation = scoped_operations.find_by!(operation_id: params[:id])
    return redirect_to telegram_root_path, alert: "Completed operations cannot be cancelled." if %w[completed failed conflicted cancelled].include?(operation.status)

    ApplicationRecord.transaction do
      operation.operation_steps.where(status: "planned").update_all(status: "cancelled", updated_at: Time.current)
      operation.transition_to!("cancelled")
    end
    redirect_to telegram_root_path, notice: "Operation cancelled before dispatch."
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end

  def rollback
    operation = scoped_operations.find_by!(operation_id: params[:id])
    rollback = Telegram::OperationFactory.new(account: operation.telegram_account, client: Telegram::ClientRegistry.client_for(operation.telegram_account)).rollback(operation)
    redirect_to telegram_root_path, notice: "Rollback #{rollback.operation_id} is ready for confirmation."
  rescue ActiveRecord::RecordNotFound
    head :not_found
  rescue Telegram::ClientNotConfigured, Telegram::PreflightConflict, Telegram::ClientResponseError, ArgumentError => error
    redirect_to telegram_root_path, alert: error.message
  end

  private

  def scoped_operations
    current_module_user.telegram_account&.operations || Operation.none
  end
end
