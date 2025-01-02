defmodule FlightsTest do
  use ExUnit.Case
  doctest Flights

  test "greets the world" do
    assert Flights.hello() == :world
  end
end
