defmodule Worth.Telemetry do
  use Agent

  def start_link(_opts) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  def span(event_prefix, metadata \\ %{}, fun) do
    start = System.monotonic_time()

    try do
      result = fun.()
      duration = System.monotonic_time() - start

      :telemetry.execute(
        event_prefix ++ [:stop],
        %{duration: duration},
        metadata
      )

      result
    rescue
      e ->
        duration = System.monotonic_time() - start

        :telemetry.execute(
          event_prefix ++ [:exception],
          %{duration: duration, kind: :error},
          Map.put(metadata, :error, Exception.message(e))
        )

        reraise e, __STACKTRACE__
    end
  end
end
