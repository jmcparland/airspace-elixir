defmodule Airspace.Flight do
  use GenServer
  require Logger

  def start(adsb) do
    icao = Enum.at(adsb, 4)
    GenServer.start(__MODULE__, adsb, name: {:via, Registry, {Airspace.Registry, icao}})
  end

  @impl true
  def init(adsb) do
    icao = Enum.at(adsb, 4)

    initial_state = %{
      icao: icao,
      vector: adsb,
      expire: Process.send_after(self(), :expire, 120_000),
      complete: false
    }

    GenServer.cast(Airspace.Reporter, {:report, "New: #{icao}"})

    {:ok, initial_state}
  end

  @impl true
  def handle_info(:expire, state) do
    GenServer.cast(Airspace.Reporter, {:report, "Ageoff: #{state.icao}"})
    {:stop, :normal, state}
  end

  @impl true
  def handle_cast({:update, adsb}, state) do
    updated_vector =
      Enum.zip(state.vector, adsb)
      |> Enum.map(fn
        {old, new} when new in [nil, ""] -> old
        {_, new} -> new
      end)

    cancel_expire_timer(state.expire)
    new_state = Map.put(state, :vector, updated_vector)
    new_state = Map.put(new_state, :expire, Process.send_after(self(), :expire, 120_000))

    new_state =
      if not state.complete and complete?(updated_vector) do
        GenServer.cast(Airspace.Reporter, {:report, inspect(updated_vector)})
        Map.put(new_state, :complete, true)
      else
        new_state
      end

    # GenServer.cast(Airspace.Reporter, {:report, inspect(updated_vector)})

    {:noreply, new_state}
  end

  defp complete?(vector) do
    [
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      callsign,
      altitude,
      ground_speed,
      track,
      latitude,
      longitude,
      vertical_rate | _
    ] = vector

    callsign != "" && altitude != "" && ground_speed != "" && track != "" && latitude != "" &&
      longitude != "" && vertical_rate != ""
  end

  defp cancel_expire_timer(ref) do
    Process.cancel_timer(ref)
  end
end
