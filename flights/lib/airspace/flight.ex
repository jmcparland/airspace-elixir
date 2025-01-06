defmodule Airspace.Flight do
  use GenServer
  use Ecto.Schema
  import Ecto.Changeset
  require Logger

  alias Airspace.Repo

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "flights" do
    field(:icao, :string)
    field(:first_observed_at, :utc_datetime)
    field(:first_observed_vector, {:array, :string})
    field(:complete_vector, {:array, :string})
    field(:expired_vector, {:array, :string})
    field(:metadata, :map)

    timestamps()
  end

  def changeset(flight, attrs) do
    flight
    |> cast(attrs, [
      :icao,
      :first_observed_at,
      :first_observed_vector,
      :complete_vector,
      :expired_vector,
      :metadata
    ])
    |> validate_required([:icao, :first_observed_at, :first_observed_vector])
  end

  def start(adsb) do
    Logger.info("Starting flight with ADS-B: #{inspect(adsb)}")

    icao = Enum.at(adsb, 4)

    case GenServer.start(__MODULE__, adsb, name: {:via, Registry, {Airspace.Registry, icao}}) do
      {:ok, pid} ->
        Logger.info("Flight #{icao} started")
        {:ok, pid}

      {:error, {:already_started, pid}} ->
        Logger.info("Flight #{icao} already started")
        {:error, {:already_started, pid}}

      {:error, reason} ->
        Logger.error("Failed to start flight #{icao}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @impl true
  def init(adsb) do
    icao = Enum.at(adsb, 4)
    first_observed_at = DateTime.utc_now()

    GenServer.cast(Airspace.Reporter, {:report, "New: #{icao}"})

    initial_state = %{
      icao: icao,
      vector: adsb,
      expire: Process.send_after(self(), :expire, 120_000),
      complete: false,
      callsign_scraped: :not_started,
      first_observed_at: first_observed_at,
      first_observed_vector: adsb,
      complete_vector: nil,
      expired_vector: nil,
      metadata: %{}
    }

    changeset = changeset(%Airspace.Flight{}, initial_state)

    case Repo.insert(changeset) do
      {:ok, flight} ->
        Logger.info("Flight #{icao} inserted into the database")
        # Include the primary key in the state
        {:ok, Map.put(initial_state, :id, flight.id)}

      {:error, changeset} ->
        Logger.error(
          "Failed to insert flight #{icao} into the database: #{inspect(changeset.errors)}"
        )

        {:stop, :normal, initial_state}
    end

    GenServer.cast(Airspace.Reporter, {:report, "New: #{icao}"})
  end

  @impl true
  def handle_info(:expire, state) do
    GenServer.cast(Airspace.Reporter, {:report, "Ageoff: #{state.icao}"})

    changeset =
      changeset(%Airspace.Flight{id: state.id}, %{
        expired_vector: state.vector,
        icao: state.icao,
        first_observed_at: state.first_observed_at,
        first_observed_vector: state.first_observed_vector
      })

    case Repo.update(changeset) do
      {:ok, _flight} ->
        Logger.info("Flight #{state.icao} expired vector updated in the database")

      {:error, changeset} ->
        Logger.error(
          "Failed to update expired vector for flight #{state.icao} in the database: #{inspect(changeset.errors)}"
        )
    end

    {:stop, :normal, state}
  end

  @impl true
  def handle_cast({:update, adsb}, state) do
    cancel_expire_timer(state.expire)

    updated_vector =
      Enum.zip(state.vector, adsb)
      |> Enum.map(fn
        {old, new} when new in [nil, ""] -> old
        {_, new} -> new
      end)

    new_state = Map.put(state, :vector, updated_vector)
    new_state = Map.put(new_state, :expire, Process.send_after(self(), :expire, 120_000))

    new_state =
      if not state.complete and complete?(updated_vector) do
        GenServer.cast(Airspace.Reporter, {:report, inspect(updated_vector)})
        Map.put(new_state, :complete, true)

        changeset =
          changeset(%Airspace.Flight{id: state.id}, %{
            vector: updated_vector,
            icao: state.icao,
            first_observed_at: state.first_observed_at,
            first_observed_vector: state.first_observed_vector
          })

        case Repo.update(changeset) do
          {:ok, _flight} ->
            Logger.info("Flight #{state.icao} complete vector updated in the database")

          {:error, changeset} ->
            Logger.error(
              "Failed to update complete vector for flight #{state.icao} in the database: #{inspect(changeset.errors)}"
            )
        end

        new_state
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
          new_state = Map.put(new_state, :metadata, metadata)

          changeset =
            changeset(%Airspace.Flight{id: state.id}, %{
              metadata: metadata,
              icao: state.icao,
              first_observed_at: state.first_observed_at,
              first_observed_vector: state.first_observed_vector
            })

          case Repo.update(changeset) do
            {:ok, _flight} ->
              Logger.info("Flight #{state.icao} metadata updated in the database")

            {:error, changeset} ->
              Logger.error(
                "Failed to update metadata for flight #{state.icao} in the database: #{inspect(changeset.errors)}"
              )
          end

          new_state

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
