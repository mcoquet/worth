defmodule Worth.Desktop.Bridge do
  @moduledoc """
  Coordinates with the Tauri host process via ElixirKit PubSub protocol.

  When WORTH_DESKTOP=1 is set, this module:
  - Connects to the PubSub TCP bridge started by the Rust side
  - Broadcasts the ready URL after the HTTP server starts
  - Listens for shutdown commands from the host
  """

  use GenServer

  def start_link(opts \\ []) do
    if desktop_mode?() do
      GenServer.start_link(__MODULE__, opts, name: __MODULE__)
    else
      :ignore
    end
  end

  def broadcast_ready(url) do
    if desktop_mode?() and Process.whereis(__MODULE__) do
      GenServer.cast(__MODULE__, {:broadcast, "ready:#{url}"})
    end
  end

  def broadcast_shutdown do
    if desktop_mode?() and Process.whereis(__MODULE__) do
      GenServer.cast(__MODULE__, {:broadcast, "shutdown"})
    end
  end

  @impl true
  def init(_opts) do
    case connect_to_pubsub() do
      {:ok, socket} ->
        {:ok, %{socket: socket}}

      {:error, reason} ->
        {:stop, {:pubsub_connect_failed, reason}}
    end
  end

  @impl true
  def handle_cast({:broadcast, message}, %{socket: socket} = state) do
    send_frame(socket, "worth", message)
    {:noreply, state}
  end

  @impl true
  def handle_info({:tcp, socket, data}, %{socket: socket} = state) do
    case parse_frame(data) do
      {:ok, "quit", _payload} ->
        send_frame(socket, "worth", "ack:quit")
        System.stop(0)
        {:noreply, state}

      {:ok, "open", path} ->
        Phoenix.PubSub.broadcast(Worth.PubSub, "desktop", {:open, path})
        {:noreply, state}

      _ ->
        {:noreply, state}
    end
  end

  def handle_info({:tcp_closed, _socket}, _state) do
    {:stop, :tcp_closed}
  end

  def handle_info({:tcp_error, _socket, reason}, _state) do
    {:stop, {:tcp_error, reason}}
  end

  defp connect_to_pubsub do
    case System.get_env("WORTH_PUBSUB") do
      nil ->
        {:error, :no_pubsub_env}

      addr ->
        [host, port] = String.split(String.replace(addr, "tcp://", ""), ":")
        :gen_tcp.connect(String.to_charlist(host), String.to_integer(port), [:binary, active: true])
    end
  end

  defp send_frame(socket, topic, payload) do
    topic_bytes = byte_size(topic)
    frame = <<1::8, topic_bytes::8, topic::binary, payload::binary>>
    length = byte_size(frame)
    :gen_tcp.send(socket, <<length::32-big, frame::binary>>)
  end

  defp parse_frame(<<_length::32-big, 1::8, topic_len::8, topic::binary-size(topic_len), payload::binary>>) do
    {:ok, topic, payload}
  end

  defp parse_frame(_), do: :error

  defp desktop_mode?, do: System.get_env("WORTH_DESKTOP") == "1"
end
