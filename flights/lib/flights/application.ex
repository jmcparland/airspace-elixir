defmodule Flights.Application do
  use Application
  require Logger

  def start(_type, _args) do
    children = [
      {Flights.TCPListener, []}
    ]

    opts = [strategy: :one_for_one, name: Flights.Supervisor]
    {:ok, supervisor_pid} = Supervisor.start_link(children, opts)
    Logger.info("Supervisor PID: #{inspect(supervisor_pid)}")

    # Retrieve and log the process ID of the Flights.TCPListener GenServer
    case Supervisor.which_children(Flights.Supervisor) do
      [{_, child_pid, _, _} | _] ->
        Logger.info("Flights.TCPListener process ID: #{inspect(child_pid)}")
        send(child_pid, :fred)
      _ ->
        Logger.error("Failed to retrieve Flights.TCPListener process ID")
    end

    {:ok, supervisor_pid}
  end
end
