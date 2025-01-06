import Config

config :airspace, Airspace.TCPListener,
  host: {192, 168, 6, 77},
  port: 30003,
  airspace_dump_interval: 5_000,
  ageoff_threshold: 2 * 60 * 1000

config :airspace, Airspace.Repo,
  username: "airspace",
  password: "airspace",
  database: "airspace",
  hostname: "10.41.0.167",
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

config :airspace, ecto_repos: [Airspace.Repo]

config :ecto, json_library: Jason
