defmodule AirspaceWeb.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      AirspaceWeb.Telemetry,
      # Start a worker by calling: AirspaceWeb.Worker.start_link(arg)
      # {AirspaceWeb.Worker, arg},
      # Start to serve requests, typically the last entry
      AirspaceWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: AirspaceWeb.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    AirspaceWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
