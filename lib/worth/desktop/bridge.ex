defmodule Worth.Desktop.Bridge do
  @moduledoc """
  Coordinates with the Tauri host process via TCP PubSub protocol.

  When WORTH_DESKTOP=1 is set, this module:
  - Connects to the PubSub TCP bridge started by the Rust side
  - Broadcasts the ready URL after the HTTP server starts
  - Listens for quit commands from the host
  - Broadcasts shutdown when the application stops
  """

  use GenServer

  require Logger

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
    case connect_to_pubsub(max_retries: 30, retry_interval: 1000) do
      {:ok, socket} ->
        Logger.info("Desktop.Bridge: connected to Tauri PubSub")
        Process.send_after(self(), :broadcast_ready, 500)
        {:ok, %{socket: socket, buffer: <<>>}}

      {:error, reason} ->
        Logger.error("Desktop.Bridge: failed to connect to PubSub: #{inspect(reason)}")
        {:ok, %{socket: nil, buffer: <<>>}}
    end
  end

  @impl true
  def handle_cast({:broadcast, _message}, %{socket: nil} = state) do
    Logger.warning("Desktop.Bridge: dropping message, no socket connection")
    {:noreply, state}
  end

  def handle_cast({:broadcast, message}, %{socket: socket} = state) do
    send_frame(socket, "worth", message)
    {:noreply, state}
  end

  @impl true
  def handle_info(:broadcast_ready, state) do
    url = Worth.Boot.url()
    broadcast_ready(url)
    {:noreply, state}
  end

  def handle_info({:tcp, socket, data}, %{socket: socket, buffer: buffer} = state) do
    new_buffer = <<buffer::binary, data::binary>>
    {messages, remaining} = parse_frames(new_buffer)

    new_state =
      Enum.reduce(messages, state, fn
        {:ok, "quit", _payload}, acc ->
          Logger.info("Desktop.Bridge: received quit command from Tauri")
          send_frame(socket, "worth", "ack:quit")
          System.stop(0)
          acc

        {:ok, "open", path}, acc ->
          Phoenix.PubSub.broadcast(Worth.PubSub, "desktop", {:open, path})
          acc

        _other, acc ->
          acc
      end)

    {:noreply, %{new_state | buffer: remaining}}
  end

  def handle_info({:tcp_closed, _socket}, state) do
    Logger.error("Desktop.Bridge: TCP connection closed by Tauri")
    {:stop, :tcp_closed, state}
  end

  def handle_info({:tcp_error, _socket, reason}, state) do
    Logger.error("Desktop.Bridge: TCP error: #{inspect(reason)}")
    {:stop, {:tcp_error, reason}, state}
  end

  defp connect_to_pubsub(opts) do
    retries = Keyword.get(opts, :max_retries, 30)
    interval = Keyword.get(opts, :retry_interval, 1000)
    connect_loop(retries, interval)
  end

  defp connect_loop(0, _interval), do: {:error, :max_retries_exceeded}

  defp connect_loop(retries, interval) do
    case System.get_env("WORTH_PUBSUB") do
      nil ->
        if retries == 1 do
          {:error, :no_pubsub_env}
        else
          Process.sleep(interval)
          connect_loop(retries - 1, interval)
        end

      addr ->
        case parse_pubsub_address(addr) do
          {:ok, host, port} ->
            case :gen_tcp.connect(
                   String.to_charlist(host),
                   port,
                   [:binary, active: true, packet: :raw]
                 ) do
              {:ok, socket} ->
                {:ok, socket}

              {:error, reason} ->
                if retries == 1 do
                  {:error, reason}
                else
                  Process.sleep(interval)
                  connect_loop(retries - 1, interval)
                end
            end

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  defp parse_pubsub_address(addr) do
    stripped = String.replace(addr, "tcp://", "")

    case String.split(stripped, ":") do
      [host, port_str] ->
        case Integer.parse(port_str) do
          {port, ""} -> {:ok, host, port}
          _ -> {:error, {:invalid_port, port_str}}
        end

      _ ->
        {:error, {:invalid_pubsub_address, addr}}
    end
  end

  defp send_frame(socket, topic, payload) do
    topic_bytes = String.to_charlist(topic)
    topic_len = length(topic_bytes)
    payload_bytes = String.to_charlist(payload)

    inner = [1, topic_len | topic_bytes] ++ payload_bytes
    frame_len = IO.iodata_length(inner)

    :gen_tcp.send(socket, [<<frame_len::32-big>> | inner])
  end

  defp parse_frames(buffer) do
    parse_frames_loop(buffer, [])
  end

  defp parse_frames_loop(buffer, acc) do
    case parse_frame(buffer) do
      {:ok, topic, payload, rest} ->
        parse_frames_loop(rest, [{:ok, topic, payload} | acc])

      :incomplete ->
        {Enum.reverse(acc), buffer}

      :error ->
        {Enum.reverse(acc), <<>>}
    end
  end

  defp parse_frame(<<length::32-big, rest::binary>>) when byte_size(rest) >= length do
    <<frame::binary-size(length), remaining::binary>> = rest

    case frame do
      <<1::8, topic_len::8, topic::binary-size(topic_len), payload::binary>> ->
        {:ok, topic, payload, remaining}

      _ ->
        :error
    end
  end

  defp parse_frame(_) do
    :incomplete
  end

  defp desktop_mode?, do: System.get_env("WORTH_DESKTOP") == "1"
end
