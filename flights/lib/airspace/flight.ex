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
      complete: false,
      callsign_scraped: :not_started
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

    callsign = Enum.at(updated_vector, 10)

    new_state =
      if callsign != "" and state.callsign_scraped == :not_started do
        GenServer.cast(self(), {:initiate_scrape, callsign})
        Map.put(new_state, :callsign_scraped, :in_progress)
      else
        new_state
      end

    {:noreply, new_state}
  end

  def handle_cast({:initiate_scrape, callsign}, state) do
    task = Task.async(fn -> callsign_scrape(callsign) end)

    new_state =
      case Task.await(task, 5_000) do
        {:ok, metadata} ->
          GenServer.cast(Airspace.Reporter, {:report, inspect(metadata)})
          new_state = Map.put(state, :callsign_scraped, :complete)
          Map.put(new_state, :metadata, metadata)

        _ ->
          Logger.error("Failed to scrape metadata for #{callsign}")
          Map.put(state, :callsign_scraped, :failed)
      end

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

  def callsign_scrape(callsign) do
    cs = String.trim_trailing(callsign)
    {:ok, html} = WebScraper.fetch_page("https://www.flightaware.com/live/flight/#{cs}")
    {:ok, parsed_html} = WebScraper.parse_html(html)
    meta_tags = Floki.find(parsed_html, "meta")

    meta_dict =
      Enum.reduce(meta_tags, %{}, fn {"meta", attrs, _}, acc ->
        case Enum.find(attrs, fn {key, _} -> key in ["name", "property"] end) do
          {_key, name} ->
            case Enum.find(attrs, fn {key, _} -> key == "content" end) do
              {"content", content} ->
                Map.put(acc, name, content)

              _ ->
                acc
            end

          _ ->
            acc
        end
      end)

    meta_dict = %{
      description: Regex.replace(~r/^Track\s+/, meta_dict["og:description"], ""),
      origin: meta_dict["origin"],
      destination: meta_dict["destination"],
      url: meta_dict["og:url"]
    }

    {:ok, meta_dict}
  end
end
