defmodule Airspace.Reporter do
  use GenServer
  require Logger

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(_) do
    Logger.info("Tracker Initializing")
    {:ok, %{}}
  end

  @impl true
  def handle_cast(%{event: event, message: message} = msg, state) when is_list(message) do
    Logger.info("#{event}: #{inspect(message)}")

    Phoenix.PubSub.broadcast(Airspace.PubSub, "flight_events", msg)

    {:noreply, state}
  end

  @impl true
  def handle_cast(%{event: event, message: message} = msg, state) when is_binary(message) do
    Logger.info("#{event}: #{inspect(message)}")
    {:noreply, state}
  end

  @impl true
  def handle_cast(%{event: event, message: message} = msg, state) do
    Logger.info("Unhandled event #{event} with message: #{inspect(message)}")
    {:noreply, state}
  end
end
