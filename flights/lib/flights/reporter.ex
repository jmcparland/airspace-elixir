defmodule Flights.Reporter do
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
  def handle_cast({:report, msg}, state) do
    Logger.info("Report: #{msg}")
    {:noreply, state}
  end
end
