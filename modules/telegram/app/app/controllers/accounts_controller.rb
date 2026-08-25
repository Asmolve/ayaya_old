class AccountsController < ApplicationController
  include AyayaIdentity

  def disconnect
    account = current_module_user.telegram_account
    return head :not_found unless account&.id == params[:id].to_i
    return redirect_to telegram_root_path, alert: "Explicit confirmation is required." unless params[:confirm] == "disconnect"

    Telegram::DisconnectAccount.new(account: account, client: Telegram::ClientRegistry.client_for(account)).call
    redirect_to telegram_root_path, notice: "Telegram credentials were removed."
  rescue Telegram::ClientNotConfigured => error
    redirect_to telegram_root_path, alert: error.message
  end

  def connect
    account = account_for_connection
    Telegram::AuthenticationFlow.new(account: account, client: Telegram::ClientRegistry.client_for(account)).start_phone(**connection_params)
    redirect_to telegram_root_path, notice: "Enter the Telegram code."
  rescue Telegram::ClientNotConfigured, Telegram::ClientResponseError, ArgumentError => error
    redirect_to telegram_root_path, alert: error.message
  end

  def submit_code
    authenticate!(:submit_code, code: params[:code])
  end

  def submit_password
    authenticate!(:submit_password, password: params[:password])
  end

  def start_qr
    account = account_for_connection
    Telegram::AuthenticationFlow.new(account: account, client: Telegram::ClientRegistry.client_for(account)).start_qr
    redirect_to telegram_root_path, notice: "Scan the QR code in Telegram."
  rescue Telegram::ClientNotConfigured, Telegram::ClientResponseError, ArgumentError => error
    redirect_to telegram_root_path, alert: error.message
  end

  def poll_qr
    authenticate!(:poll_qr)
  end

  def update_read_only
    account = current_module_user.telegram_account
    return redirect_to telegram_root_path, alert: "Connect Telegram first." unless account

    account.update!(read_only: ActiveModel::Type::Boolean.new.cast(params[:read_only]))
    redirect_to telegram_root_path, notice: account.read_only? ? "Read-only mode is enabled." : "Changes can now be prepared for confirmation."
  end

  private

  def account_for_connection
    current_module_user.telegram_account || current_module_user.create_telegram_account!(telegram_account_id: "pending-#{current_module_user.core_user_id}", read_only: true)
  end

  def connection_params
    params.permit(:phone, :api_id, :api_hash).to_h.symbolize_keys
  end

  def authenticate!(method, **arguments)
    account = current_module_user.telegram_account
    return redirect_to telegram_root_path, alert: "Connect Telegram first." unless account

    Telegram::AuthenticationFlow.new(account: account, client: Telegram::ClientRegistry.client_for(account)).public_send(method, **arguments)
    redirect_to telegram_root_path, notice: "Telegram authentication state updated."
  rescue Telegram::ClientNotConfigured, Telegram::ClientResponseError, ArgumentError, KeyError => error
    redirect_to telegram_root_path, alert: error.message
  end
end
