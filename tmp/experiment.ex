defmodule HelloServer do
  use GenServer

  def handle_call(msg, _from, state) do
    {:reply, "Received in call: #{msg}", state}
  end

  def handle_cast(msg, state) do
    :timer.sleep 2000
    IO.puts "Received in cast: #{msg}"
    {:noreply, state}
  end

  def handle_info(msg, state) do
    IO.puts "Received in info: #{msg}"
    {:noreply, state}
  end
end
