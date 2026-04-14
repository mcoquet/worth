defmodule Worth.Repo.Migrations.CreateMetricsTables do
  use Ecto.Migration

  def change do
    create table(:session_metrics, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:session_id, :string, null: false)
      add(:run_id, :string)
      add(:strategy, :string, null: false, default: "default")
      add(:mode, :string, null: false)
      add(:workspace, :string, null: false)
      add(:started_at, :utc_datetime_usec, null: false)
      add(:completed_at, :utc_datetime_usec)
      add(:status, :string, null: false, default: "running")
      add(:total_cost_usd, :float, default: 0.0)
      add(:total_tokens_in, :integer, default: 0)
      add(:total_tokens_out, :integer, default: 0)
      add(:total_turns, :integer, default: 0)
      add(:total_tool_calls, :integer, default: 0)
      add(:prompt_hash, :string)
      add(:model_id, :string)

      timestamps(type: :utc_datetime_usec)
    end

    create(index(:session_metrics, [:strategy, :started_at]))
    create(index(:session_metrics, [:run_id]))
    create(index(:session_metrics, [:prompt_hash]))
    create(unique_index(:session_metrics, [:session_id]))

    create table(:turn_metrics, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:session_id, :string, null: false)
      add(:turn_number, :integer, null: false)
      add(:started_at, :utc_datetime_usec, null: false)
      add(:duration_ms, :integer)
      add(:cost_usd, :float, default: 0.0)
      add(:tokens_in, :integer, default: 0)
      add(:tokens_out, :integer, default: 0)
      add(:stop_reason, :string)
      add(:model_id, :string)
      add(:phase, :string)

      timestamps(type: :utc_datetime_usec)
    end

    create(index(:turn_metrics, [:session_id]))

    create table(:tool_call_metrics, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:session_id, :string, null: false)
      add(:turn_number, :integer, null: false)
      add(:tool_name, :string, null: false)
      add(:called_at, :utc_datetime_usec, null: false)
      add(:duration_ms, :integer)
      add(:success, :boolean, default: true)
      add(:error_type, :string)
      add(:result_size_bytes, :integer)

      timestamps(type: :utc_datetime_usec)
    end

    create(index(:tool_call_metrics, [:session_id]))
    create(index(:tool_call_metrics, [:tool_name]))

    create table(:strategy_metrics, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:session_id, :string, null: false)
      add(:metric_key, :string, null: false)
      add(:metric_value, :float, null: false)
      add(:recorded_at, :utc_datetime_usec, null: false)
      add(:metadata, :text)

      timestamps(type: :utc_datetime_usec)
    end

    create(index(:strategy_metrics, [:metric_key]))
  end
end
