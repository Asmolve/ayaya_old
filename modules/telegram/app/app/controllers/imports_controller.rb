class ImportsController < ApplicationController
  include AyayaIdentity

  def create
    account = current_module_user.telegram_account
    return redirect_to telegram_root_path, alert: "Connect Telegram first." unless account

    Telegram::ReadOnlyImport.new(account: account, client: Telegram::ClientRegistry.client_for(account)).call
    redirect_to telegram_root_path, notice: "Read-only import completed."
  end
end
