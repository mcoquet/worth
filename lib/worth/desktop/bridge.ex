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
        Process.send_after(self(), :broadcast_ready, 500)
        {:ok, %{socket: socket, buffer: <<>>}}

      {:error, reason} ->
        if desktop_mode?() do
          IO.warn("Desktop.Bridge: failed to connect to PubSub: #{inspect(reason)}")
        end

        {:ok, %{socket: nil, buffer: <<>>}}
    end
  end

  @impl true
  def handle_cast({:broadcast, message}, %{socket: nil} = state) do
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
    IO.warn("Desktop.Bridge: TCP connection closed by Rust side")
    {:stop, :tcp_closed, state}
  end

  def handle_info({:tcp_error, _socket, reason}, state) do
    IO.warn("Desktop.Bridge: TCP error: #{inspect(reason)}")
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
        [host, port] = String.split(String.replace(addr, "tcp://", ""), ":")

        case :gen_tcp.connect(
               String.to_charlist(host),
               String.to_integer(port),
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
    end
  end

  defp send_frame(socket, topic, payload) do
    topic_bytes = topic |> String.to_charlist()
    topic_len = length(topic_bytes)

    inner = [1, topic_len | topic_bytes] ++ String.to_charlist(payload)
    frame_len = length(inner)

    header = :binary.encode_unsigned(frame_len, 32)
    :gen_tcp.send(socket, [header | inner])
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
