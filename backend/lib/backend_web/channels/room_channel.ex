defmodule BackendWeb.RoomChannel do
  use BackendWeb, :channel

  @impl true
  def join("room:" <> room_id, _payload, socket) do
    with {:ok, claims} <- Backend.Auth.verify_token(socket.assigns.token),
         {:ok, user} <- Backend.Repo.get_user_by_id(claims["user_id"]) do
      latest_messages = Backend.Repo.get_latest_messages(room_id, 10)

      socket =
        socket
        |> assign(:room_id, room_id)
        |> assign(:user_id, user.id)

      {:ok, %{messages: latest_messages}, socket}
    else
      _ ->
        {:error, %{reason: "unauthorized"}}
    end
  end

  @impl true
  def handle_in("new_msg", %{"content" => content}, socket) do
    room_id = socket.assigns.room_id
    user_id = socket.assigns.user_id
    {:ok, user} = Backend.Repo.get_user_by_id(user_id)

    id = UUID.uuid4()
    Backend.Repo.insert_message(id, room_id, user_id, content)

    broadcast!(socket, "new_msg", %{
      id: id,
      sender: user.username,
      content: content
    })

    {:noreply, socket}
  end
end
