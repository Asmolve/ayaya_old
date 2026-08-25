require "test_helper"
require Rails.root.join("db/migrate/20260821010000_add_durable_organizer_state")

class AddDurableOrganizerStateTest < ActiveSupport::TestCase
  test "backfills legacy multi-step operations deterministically and conflicts unsafe active work" do
    connection = ActiveRecord::Base.connection
    connection.execute <<~SQL
      CREATE TEMPORARY TABLE telegram_accounts (id bigint PRIMARY KEY);
      CREATE TEMPORARY TABLE operations (id bigint PRIMARY KEY, status varchar NOT NULL, completed_at timestamp, created_at timestamp NOT NULL, updated_at timestamp NOT NULL);
      CREATE TEMPORARY TABLE operation_steps (id bigint PRIMARY KEY, operation_id bigint NOT NULL, status varchar NOT NULL, expected_postcondition jsonb NOT NULL DEFAULT '{}', error_json jsonb NOT NULL DEFAULT '{}', created_at timestamp NOT NULL, updated_at timestamp NOT NULL);
    SQL
    timestamp = Time.current.change(usec: 0)
    connection.execute("INSERT INTO telegram_accounts (id) VALUES (1)")
    connection.execute("INSERT INTO operations (id, status, created_at, updated_at) VALUES (1, 'applying', '#{timestamp}', '#{timestamp}'), (2, 'completed', '#{timestamp}', '#{timestamp}')")
    connection.execute("INSERT INTO operation_steps (id, operation_id, status, created_at, updated_at) VALUES (30, 1, 'planned', '#{timestamp}', '#{timestamp}'), (10, 1, 'planned', '#{timestamp}', '#{timestamp}'), (20, 2, 'confirmed', '#{timestamp}', '#{timestamp}')")

    AddDurableOrganizerState.new.up

    active_steps = connection.select_all("SELECT id, sequence, status, request_payload FROM operation_steps WHERE operation_id = 1 ORDER BY sequence").to_a
    assert_equal [ 10, 30 ], active_steps.pluck("id")
    assert_equal [ 0, 1 ], active_steps.pluck("sequence")
    assert_equal [ "cancelled", "cancelled" ], active_steps.pluck("status")
    assert_equal [ { "legacy_backfill" => true }, { "legacy_backfill" => true } ], active_steps.map { |row| JSON.parse(row.fetch("request_payload")) }
    assert_equal "conflicted", connection.select_value("SELECT status FROM operations WHERE id = 1")
    assert_equal "completed", connection.select_value("SELECT status FROM operations WHERE id = 2")
  ensure
    connection.execute("DROP TABLE IF EXISTS operation_steps, operations, telegram_accounts") if connection
  end
end
