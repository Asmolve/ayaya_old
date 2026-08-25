class AddRateLimitPauseToTelegramAccounts < ActiveRecord::Migration[8.1]
  def change
    add_column :telegram_accounts, :rate_limited_until, :datetime
    add_index :telegram_accounts, :rate_limited_until
  end
end
