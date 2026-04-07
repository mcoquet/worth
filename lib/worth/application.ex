defmodule Worth.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Worth.Repo,
      {Phoenix.PubSub, name: Worth.PubSub},
      {Registry, keys: :unique, name: Worth.Registry},
      {Task.Supervisor, name: Worth.TaskSupervisor},
      Worth.Telemetry,
      Worth.Brain.Supervisor
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Worth.Supervisor)
  end

  @impl true
  def stop(_state) do
    :ok
  end
end
