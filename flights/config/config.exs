import Config

config :flights, Flights.TCPListener,
  host: {192, 168, 6, 77},
  port: 30003,
  airspace_dump_interval: 5_000,
  ageoff_threshold: 2 * 60 * 1000
