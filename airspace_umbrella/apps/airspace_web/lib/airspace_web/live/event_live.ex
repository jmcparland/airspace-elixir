defmodule AirspaceWeb.EventLive do
  use AirspaceWeb, :live_view

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Airspace.PubSub, "flight_events")
    end

    {:ok, assign(socket, :events, [])}
  end

  def handle_info(%{event: event, message: message}, socket) do
    new_event = %{event: event, message: message}
    {:noreply, update(socket, :events, fn events -> [new_event | events] |> Enum.take(10) end)}
  end

  def render(assigns) do
    ~H"""
    <div>
      <h1>Flight Events</h1>
      <ul>
        <%= for event <- @events do %>
          <li>
            <strong><%= event.event %>:</strong>
            <%= for message <- event.message do %>
              <span><%= message %></span>
            <% end %>
          </li>
        <% end %>
      </ul>
    </div>
    """
  end
end
