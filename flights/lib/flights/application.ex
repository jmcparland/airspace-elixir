defmodule Flights.Application do
  use Application
  require Logger

  def start(_type, _args) do
    children = [
      {Registry, keys: :unique, name: Flights.Registry},
      Flights.TCPListener,
      Flights.Reporter
    ]

    opts = [strategy: :one_for_one, name: Flights.Supervisor]
    {:ok, supervisor_pid} = Supervisor.start_link(children, opts)
    Logger.info("Supervisor PID: #{inspect(supervisor_pid)}")

    {:ok, supervisor_pid}
  end
end
