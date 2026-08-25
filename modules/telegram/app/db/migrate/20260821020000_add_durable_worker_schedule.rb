class AddDurableWorkerSchedule < ActiveRecord::Migration[8.1]
  def change
    add_column :operations, :execution_requested_at, :datetime
    add_column :operations, :next_attempt_at, :datetime
    add_column :operations, :attempt_count, :integer, null: false, default: 0
    add_column :operations, :worker_locked_until, :datetime
    add_index :operations, %i[status execution_requested_at next_attempt_at], name: "index_operations_for_durable_worker"
  end
end
