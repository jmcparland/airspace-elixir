defmodule Flights.TCPListener do
  use GenServer
  require Logger

  @host {192, 168, 6, 77}
  @port 30003
  @airspace_dump_interval 5_000
  @ageoff_threshold 2 * 60 * 1000

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(state) do
    Logger.info("GenServer Initializing")
    initial_state = Map.put(state, :flights, %{})
    schedule_airspace_inspection(@airspace_dump_interval)
    schedule_airspace_ageoff(@ageoff_threshold)
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

  @impl true
  def handle_info({:tcp, socket, data}, state) do
    trimmed_data = String.trim(data)
    new_state = process_observation(trimmed_data, state)
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
    schedule_airspace_inspection(@airspace_dump_interval)
    {:noreply, state}
  end

  @impl true
  def handle_info(:airspace_ageoff, state) do
    Logger.info("Removing outdated flights")
    new_state = remove_outdated_flights(state)
    schedule_airspace_ageoff(@ageoff_threshold)
    {:noreply, new_state}
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

  defp process_observation(line, state) do
    line
    |> String.trim_trailing("\r")
    |> String.split(",")
    |> case do
      [_, _, _, _, id | _] = list ->
        current_time = :os.system_time(:millisecond)

        new_flights =
          Map.update(state[:flights], id, {list, current_time}, fn {old_list, _} ->
            updated_list =
              Enum.zip(old_list, list)
              |> Enum.map(fn
                {old, new} when new in [nil, ""] -> old
                {_, new} -> new
              end)

            {updated_list, current_time}
          end)

        Map.put(state, :flights, new_flights)

      _ ->
        state
    end
  end

  defp remove_outdated_flights(state) do
    current_time = :os.system_time(:millisecond)

    new_flights =
      state[:flights]
      |> Enum.filter(fn {_id, {_list, timestamp}} ->
        current_time - timestamp <= @ageoff_threshold
      end)
      |> Enum.into(%{})

    Map.put(state, :flights, new_flights)
  end

  defp schedule_airspace_inspection(delay_ms) do
    Logger.info("Scheduling airspace inspection")
    Process.send_after(self(), :display_state, delay_ms)
  end

  defp schedule_airspace_ageoff(delay_ms) do
    Logger.info("Scheduling airspace ageoff")
    Process.send_after(self(), :airspace_ageoff, delay_ms)
  end
end
