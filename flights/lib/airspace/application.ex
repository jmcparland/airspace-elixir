defmodule Airspace.Application do
  use Application
  require Logger

  def start(_type, _args) do
    children = [
      {Registry, keys: :unique, name: Airspace.Registry},
      Airspace.TCPListener,
      Airspace.Reporter
    ]

    opts = [strategy: :one_for_one, name: Airspace.Supervisor]
    {:ok, supervisor_pid} = Supervisor.start_link(children, opts)
    Logger.info("Supervisor PID: #{inspect(supervisor_pid)}")

    {:ok, supervisor_pid}
  end
end
