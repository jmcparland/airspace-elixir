defmodule Airspace.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Airspace.Repo,
      {DNSCluster, query: Application.get_env(:airspace, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Airspace.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Airspace.Finch},
      # Start a worker by calling: Airspace.Worker.start_link(arg)
      # {Airspace.Worker, arg}
      {Registry, keys: :unique, name: Airspace.Registry},
      Airspace.TCPListener,
      Airspace.Reporter
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Airspace.Supervisor)
  end
end
