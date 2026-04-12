defmodule WorthWeb.ConnCase do
  @moduledoc """
  Test case template for tests requiring a connection (LiveView, controllers).

  Sets up database sandbox and provides a connected test socket.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      @endpoint WorthWeb.Endpoint

      import Plug.Conn
      import Phoenix.ConnTest
      import Phoenix.LiveViewTest

      use Phoenix.VerifiedRoutes,
        endpoint: WorthWeb.Endpoint,
        router: WorthWeb.Router,
        statics: WorthWeb.static_paths()
    end
  end

  setup tags do
    Worth.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
