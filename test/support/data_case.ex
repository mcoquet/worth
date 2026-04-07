defmodule Worth.DataCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      alias Worth.Repo
      import Ecto.Query
    end
  end

  setup tags do
    Worth.DataCase.setup_sandbox(tags)
    :ok
  end

  def setup_sandbox(tags) do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(Worth.Repo, shared: not tags[:async])

    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
  end
end
