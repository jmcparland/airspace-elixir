defmodule Airspace.Repo do
  use Ecto.Repo,
    otp_app: :airspace,
    adapter: Ecto.Adapters.Postgres
end
