# This file is responsible for configuring your umbrella
# and **all applications** and their dependencies with the
# help of the Config module.
#
# Note that all applications in your umbrella share the
# same configuration and dependencies, which is why they
# all use the same configuration file. If you want different
# configurations or dependencies per app, it is best to
# move said applications out of the umbrella.
import Config

# config :airspace, Airspace.TCPListener,
#   host: {192, 168, 6, 77},
#   port: 30003,
#   airspace_dump_interval: 5_000,
#   ageoff_threshold: 2 * 60 * 1000

# config :airspace, Airspace.Repo,
#   username: "airspace",
#   password: "airspace",
#   database: "airspace_umbrella",
#   hostname: "10.41.0.167",
#   show_sensitive_data_on_connection_error: true,
#   pool_size: 10

config :ecto, json_library: Jason

# Configure Mix tasks and generators
config :airspace,
  ecto_repos: [Airspace.Repo]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :airspace, Airspace.Mailer, adapter: Swoosh.Adapters.Local

config :airspace_web,
  ecto_repos: [Airspace.Repo],
  generators: [context_app: :airspace]

# Configures the endpoint
config :airspace_web, AirspaceWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: AirspaceWeb.ErrorHTML, json: AirspaceWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Airspace.PubSub,
  live_view: [signing_salt: "ynBjldHE"]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  airspace_web: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../apps/airspace_web/assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.3",
  airspace_web: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../apps/airspace_web/assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
