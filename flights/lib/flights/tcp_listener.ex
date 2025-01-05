defmodule Flights.TCPListener do
  use GenServer
  require Logger

  @host Application.compile_env(:flights, Flights.TCPListener, [])[:host]
  @port Application.compile_env(:flights, Flights.TCPListener, [])[:port]

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(state) do
    Logger.info("TCPListener Initializing")
    initial_state = Map.put(state, :flights, %{})
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
    _ = process_observation(trimmed_data)
    :inet.setopts(socket, active: :once)
    {:noreply, state}
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
  def terminate(_reason, %{socket: socket}) do
    :gen_tcp.close(socket)
    :ok
  end

  @impl true
  def terminate(_reason, _state) do
    :ok
  end

  defp format_ip({a, b, c, d}), do: "#{a}.#{b}.#{c}.#{d}"

  defp process_observation(line) do
    line
    |> String.trim_trailing("\r")
    |> String.split(",")
    |> case do
      [_, _, _, _, icao | _] = adsb ->
        flight_name = {:global, icao}

        case GenServer.whereis(flight_name) do
          nil ->
            {:ok, _pid} = Flights.Flight.start(adsb)

          pid ->
            GenServer.cast(pid, {:update, adsb})
        end

      _ ->
        :ignore
    end
  end

  # TESTING

  def list_flight_processes do
    Process.registered()
    |> Enum.filter(fn
      {:global, _icao} -> true
      _ -> false
    end)
  end

  # New function to get the count of flight processes
  def flight_process_count do
    list_flight_processes()
    |> length()
  end
end
