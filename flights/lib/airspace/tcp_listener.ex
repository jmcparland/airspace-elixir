defmodule Airspace.TCPListener do
  use GenServer
  require Logger

  @host Application.compile_env(:airspace, Airspace.TCPListener, [])[:host]
  @port Application.compile_env(:airspace, Airspace.TCPListener, [])[:port]

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(_state) do
    Logger.info("TCPListener Initializing")
    initial_state = %{}
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
        case Registry.lookup(Airspace.Registry, icao) do
          [] ->
            {:ok, _pid} = Airspace.Flight.start(adsb)

          [{pid, _}] ->
            GenServer.cast(pid, {:update, adsb})
        end

      _ ->
        :ignore
    end
  end

  # TESTING

  def list_flight_processes do
    Registry.select(Airspace.Registry, [{{:"$1", :"$2", :"$3"}, [], [:"$1"]}])
  end

  def flight_process_count do
    list_flight_processes()
    |> length()
  end
end
