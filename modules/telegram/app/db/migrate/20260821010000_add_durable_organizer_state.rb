class AddDurableOrganizerState < ActiveRecord::Migration[8.1]
  ACTIVE_OPERATION_STATUSES = %w[planned awaiting_confirmation applying reconciling].freeze
  UNSAFE_STEP_STATUSES = %w[planned dispatched outcome_unknown].freeze

  def up
    add_column :telegram_accounts, :persisted_limits, :jsonb, null: false, default: {}
    add_column :telegram_accounts, :limits_updated_at, :datetime

    add_column :operations, :retention_until, :datetime
    add_index :operations, :retention_until

    add_column :operation_steps, :sequence, :integer
    add_column :operation_steps, :rpc, :string
    add_column :operation_steps, :request_payload, :jsonb

    execute <<~SQL.squish
      WITH ranked_steps AS (
        SELECT id, ROW_NUMBER() OVER (PARTITION BY operation_id ORDER BY created_at ASC, id ASC) - 1 AS sequence
        FROM operation_steps
      )
      UPDATE operation_steps
      SET sequence = ranked_steps.sequence
      FROM ranked_steps
      WHERE operation_steps.id = ranked_steps.id
    SQL
    execute <<~SQL.squish
      UPDATE operation_steps
      SET rpc = 'update_dialog_filter', request_payload = '{"legacy_backfill":true}'::jsonb
      WHERE rpc IS NULL AND request_payload IS NULL
    SQL
    execute <<~SQL.squish
      UPDATE operation_steps
      SET status = 'cancelled', error_json = COALESCE(error_json, '{}'::jsonb) || '{"code":"legacy_request_unavailable"}'::jsonb
      WHERE operation_id IN (SELECT id FROM operations WHERE status IN (#{quoted(ACTIVE_OPERATION_STATUSES)}))
        AND status IN (#{quoted(UNSAFE_STEP_STATUSES)})
    SQL
    execute <<~SQL.squish
      UPDATE operations
      SET status = 'conflicted', completed_at = CURRENT_TIMESTAMP
      WHERE status IN (#{quoted(ACTIVE_OPERATION_STATUSES)})
    SQL

    change_column_null :operation_steps, :sequence, false
    change_column_null :operation_steps, :rpc, false
    change_column_null :operation_steps, :request_payload, false
    change_column_default :operation_steps, :sequence, from: nil, to: 0
    change_column_default :operation_steps, :rpc, from: nil, to: "update_dialog_filter"
    change_column_default :operation_steps, :request_payload, from: nil, to: {}
    add_index :operation_steps, %i[operation_id sequence], unique: true, name: "index_operation_steps_on_operation_and_sequence"
  end

  def down
    remove_index :operation_steps, name: "index_operation_steps_on_operation_and_sequence"
    remove_column :operation_steps, :request_payload
    remove_column :operation_steps, :rpc
    remove_column :operation_steps, :sequence
    remove_index :operations, :retention_until
    remove_column :operations, :retention_until
    remove_column :telegram_accounts, :limits_updated_at
    remove_column :telegram_accounts, :persisted_limits
  end

  private

  def quoted(values)
    values.map { |value| connection.quote(value) }.join(", ")
  end
end
