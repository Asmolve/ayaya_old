require "test_helper"
require Rails.root.join("db/migrate/20260821030000_add_folder_proposals_and_ownership_state")

class AddFolderProposalsAndOwnershipStateTest < ActiveSupport::TestCase
  test "backfills confirmed ownership only when the prior immutable record matches the account, folder, and fingerprint" do
    connection = ActiveRecord::Base.connection
    connection.execute <<~SQL
      CREATE TEMPORARY TABLE telegram_accounts (id bigint PRIMARY KEY, telegram_account_id varchar NOT NULL);
      CREATE TEMPORARY TABLE folders (
        id bigint PRIMARY KEY,
        telegram_account_id bigint NOT NULL,
        telegram_folder_id bigint NOT NULL,
        managed_by_app boolean NOT NULL DEFAULT false,
        ownership_record jsonb NOT NULL DEFAULT '{}',
        remote_fingerprint varchar
      );
    SQL
    connection.execute("INSERT INTO telegram_accounts (id, telegram_account_id) VALUES (1, 'account-1'), (2, 'account-2')")
    connection.execute <<~SQL
      INSERT INTO folders (id, telegram_account_id, telegram_folder_id, managed_by_app, ownership_record, remote_fingerprint) VALUES
        (1, 1, 11, true, '{"account_id":"account-1","telegram_folder_id":11,"fingerprint":"matched"}', 'matched'),
        (2, 1, 12, true, '{"account_id":"account-2","telegram_folder_id":12,"fingerprint":"matched"}', 'matched'),
        (3, 1, 13, true, '{"account_id":"account-1","telegram_folder_id":99,"fingerprint":"matched"}', 'matched'),
        (4, 1, 14, true, '{"account_id":"account-1","telegram_folder_id":14,"fingerprint":"different"}', 'matched'),
        (5, 1, 15, false, '{"account_id":"account-1","telegram_folder_id":15,"fingerprint":"matched"}', 'matched');
    SQL

    AddFolderProposalsAndOwnershipState.new.migrate(:up)

    states = connection.select_all("SELECT id, ownership_state FROM folders ORDER BY id").to_a.to_h { |row| [ row.fetch("id"), row.fetch("ownership_state") ] }
    assert_equal({ 1 => "confirmed", 2 => "foreign", 3 => "foreign", 4 => "foreign", 5 => "foreign" }, states)
  ensure
    connection.execute("DROP TABLE IF EXISTS folder_proposals, folders, telegram_accounts") if connection
  end
end
