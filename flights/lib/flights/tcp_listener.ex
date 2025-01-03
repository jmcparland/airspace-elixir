defmodule Flights.TCPListener do
  use GenServer
  require Logger

  @host {192, 168, 6, 77}
  @port 30003
  # Interval in milliseconds
  @interval 5_000

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(state) do
    process_id = self()
    parent_id = Process.info(self(), :parent) |> elem(1)

    # send(self(), :test_message)
    Process.send_after(self(), :test_message, 10_000)

    Logger.info("GenServer Initializing")
    Logger.info("Process ID: #{inspect(process_id)}")
    Logger.info("Parent Process ID: #{inspect(parent_id)}")

    initial_state = Map.put(state, :flights, %{})

    schedule_work()
    Process.send_after(self(), :test_message, 0)

    Logger.info("Initial state: #{inspect(state)}")

    {:ok, initial_state, {:continue, :connect}}
  end

  @impl true
  def handle_continue(:connect, state) do
    case :gen_tcp.connect(@host, @port, [:binary, active: :once, packet: :line]) do
      {:ok, socket} ->
        Logger.info("Connected to #{format_ip(@host)}:#{@port}")
        {:noreply, Map.put(state, :socket, socket)}

      {:error, reason} ->
        Logger.error("Failed to connect: #{reason}")
        {:stop, reason, state}
    end
  end

  # @impl true
  # def handle_continue(:listen, %{socket: socket} = state) do
  #   case :gen_tcp.recv(socket, 0) do
  #     {:ok, data} ->
  #       trimmed_data = String.trim(data)

  #       # Logger.info(trimmed_data)

  #       new_state = process_line(trimmed_data, state)
  #       {:noreply, new_state, {:continue, :listen}}
  #     {:error, reason} ->
  #       Logger.error("Connection error: #{reason}")
  #       {:stop, reason, state}
  #   end
  # end

  @impl true
  def handle_info({:tcp, socket, data}, state) do
    trimmed_data = String.trim(data)
    new_state = process_line(trimmed_data, state)
    # Set the socket back to active once
    :inet.setopts(socket, active: :once)
    {:noreply, new_state}
  end

  @impl true
  def handle_info({:tcp_closed, _socket}, state) do
    Logger.info("Socket closed")
    {:stop, :normal, state}
  end

  @impl true
  def handle_info({:tcp_error, _socket, reason}, state) do
    Logger.error("TCP error: #{reason}")
    {:stop, reason, state}
  end

  @impl true
  def handle_info(:display_state, state) do
    Logger.info("Received :display_state message")
    IO.inspect(state[:flights], label: "Flights Dictionary")
    schedule_work()
    {:noreply, state}
  end

  @impl true
  def handle_info(:test_message, state) do
    Logger.info("Received :test_message")
    {:noreply, state}
  end

  def handle_info(msg, state) do
    Logger.warning("Unhandled message: #{inspect(msg)}")
    # {:stop, :normal, state}
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, %{socket: socket}) do
    :gen_tcp.close(socket)
    :ok
  end

  @impl true
  def terminate(_reason, _state) do
    :ok
  end

  defp format_ip({a, b, c, d}), do: "#{a}.#{b}.#{c}.#{d}"

  defp process_line(line, state) do
    line
    |> String.trim_trailing("\r")
    |> String.split(",")
    |> case do
      [_, _, _, _, id | _] = list ->
        new_flights =
          Map.update(state[:flights], id, list, fn old_list ->
            Enum.zip(old_list, list)
            |> Enum.map(fn
              {old, new} when new in [nil, ""] -> old
              {_, new} -> new
            end)
          end)

        Map.put(state, :flights, new_flights)

      _ ->
        state
    end
  end

  defp schedule_work() do
    Logger.info("Scheduling work")
    Process.send_after(self(), :display_state, @interval)
  end
end
