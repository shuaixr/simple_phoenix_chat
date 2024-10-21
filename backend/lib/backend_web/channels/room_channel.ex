defmodule BackendWeb.RoomChannel do
  use BackendWeb, :channel

  @impl true
  def join("room:" <> room_id, _payload, socket) do
    latest_messages = Backend.Repo.get_latest_messages(room_id, 10)
    {:ok, %{messages: latest_messages}, assign(socket, :room_id, room_id)}
  end

  @impl true
  def handle_in("new_msg", %{"sender" => sender, "content" => content}, socket) do
    room_id = socket.assigns.room_id
    id = UUID.uuid4()
    Backend.Repo.insert_message(id, room_id, sender, content)

    broadcast!(socket, "new_msg", %{
      id: id,
      sender: sender,
      content: content
    })

    {:noreply, socket}
  end
end
