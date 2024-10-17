defmodule BackendWeb.RoomChannel do
  use BackendWeb, :channel

  @impl true
  def join("room:" <> _room_id, payload, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_in("new_msg", %{"id" => id, "sender" => sender, "content" => content}, socket) do
    broadcast!(socket, "new_msg", %{
      id: id,
      sender: sender,
      content: content
    })

    {:noreply, socket}
  end
end
