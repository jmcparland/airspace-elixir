defmodule Flights.Application do
  use Application

  def start(_type, _args) do
    children = [
      {Flights.TCPListener, []}
    ]

    opts = [strategy: :one_for_one, name: Flights.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
