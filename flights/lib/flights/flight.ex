defmodule Flights.Flight do
  use GenServer
  require Logger

  def start(adsb) do
    icao = Enum.at(adsb, 4)
    GenServer.start(__MODULE__, adsb, name: {:global, icao})
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

    GenServer.cast(Flights.Reporter, {:report, "New: #{icao}"})

    {:ok, initial_state}
  end

  @impl true
  def handle_info(:expire, state) do
    GenServer.cast(Flights.Reporter, {:report, "Ageoff: #{state.icao}"})
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

    # GenServer.cast(Flights.Reporter, {:report, inspect(updated_vector)})

    {:noreply, new_state}
  end

  defp cancel_expire_timer(ref) do
    Process.cancel_timer(ref)
  end
end
