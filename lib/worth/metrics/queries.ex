defmodule Worth.Metrics.Queries do
  @moduledoc """
  Pre-built analysis queries for strategy metrics.
  """

  import Ecto.Query

  alias Worth.Metrics.Repo
  alias Worth.Metrics.Schema.SessionMetric
  alias Worth.Metrics.Schema.ToolCallMetric

  def strategy_comparison(days_back \\ 30) do
    since = DateTime.add(DateTime.utc_now(), -days_back, :day)

    Repo.all(
      from(s in SessionMetric,
        where: s.started_at >= ^since,
        group_by: s.strategy,
        select: %{
          strategy: s.strategy,
          runs: count(s.id),
          avg_cost: avg(s.total_cost_usd),
          avg_turns: avg(s.total_turns),
          success_pct:
            fragment("ROUND(100.0 * SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) * 1.0 / COUNT(*), 1)")
        }
      )
    )
  end

  def strategy_trend(days_back \\ 30) do
    since = DateTime.add(DateTime.utc_now(), -days_back, :day)

    Repo.all(
      from(s in SessionMetric,
        where: s.started_at >= ^since and s.status == "completed",
        group_by: [s.strategy, fragment("DATE(started_at)")],
        select: %{
          strategy: s.strategy,
          date: fragment("DATE(?)", s.started_at),
          avg_cost: avg(s.total_cost_usd),
          avg_turns: avg(s.total_turns)
        },
        order_by: [asc: fragment("DATE(?)", s.started_at)]
      )
    )
  end

  def tool_analysis(days_back \\ 30) do
    since = DateTime.add(DateTime.utc_now(), -days_back, :day)

    Repo.all(
      from(t in ToolCallMetric,
        where: t.called_at >= ^since,
        group_by: t.tool_name,
        select: %{
          tool_name: t.tool_name,
          calls: count(t.id),
          avg_duration_ms: avg(t.duration_ms),
          failure_count: fragment("SUM(CASE WHEN success = 0 THEN 1 ELSE 0 END)")
        },
        order_by: [desc: count(t.id)]
      )
    )
  end

  def recent_sessions(limit \\ 20) do
    Repo.all(
      from(s in SessionMetric,
        order_by: [desc: s.started_at],
        limit: ^limit,
        select: %{
          session_id: s.session_id,
          strategy: s.strategy,
          mode: s.mode,
          status: s.status,
          total_cost_usd: s.total_cost_usd,
          total_turns: s.total_turns,
          started_at: s.started_at,
          completed_at: s.completed_at
        }
      )
    )
  end

  def prompt_comparison(run_id) do
    Repo.all(
      from(s in SessionMetric,
        where: s.run_id == ^run_id,
        group_by: [s.prompt_hash, s.strategy],
        select: %{
          prompt_hash: s.prompt_hash,
          strategy: s.strategy,
          avg_cost: avg(s.total_cost_usd),
          avg_turns: avg(s.total_turns),
          runs: count(s.id)
        },
        order_by: [s.prompt_hash, asc: avg(s.total_cost_usd)]
      )
    )
  end
end
