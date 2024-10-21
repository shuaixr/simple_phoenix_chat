defmodule Backend.Repo do
  use GenServer

  @moduledoc """
  CREATE TABLE messages (
      id uuid,
      room_id text,
      sender text,
      content text,
      timestamp timestamp,
      PRIMARY KEY ((room_id), timestamp, id)
  ) WITH CLUSTERING ORDER BY (timestamp DESC);

  """
  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_) do
    {:ok, conn} = Xandra.start_link(nodes: ["127.0.0.1:9042"], keyspace: "chat")
    {:ok, %{conn: conn}}
  end

  def insert_message(id, room_id, sender, content) do
    GenServer.call(__MODULE__, {:insert_message, id, room_id, sender, content})
  end

  def get_latest_messages(room_id, limit \\ 10) do
    GenServer.call(__MODULE__, {:get_latest_messages, room_id, limit})
  end

  def handle_call({:insert_message, id, room_id, sender, content}, _from, %{conn: conn} = state) do
    statement =
      "INSERT INTO messages (id, room_id, sender, content, timestamp) VALUES (?, ?, ?, ?, toTimestamp(now()))"

    {:ok, _} =
      Xandra.execute(conn, statement, [
        {"uuid", id},
        {"text", room_id},
        {"text", sender},
        {"text", content}
      ])

    {:reply, :ok, state}
  end

  def handle_call({:get_latest_messages, room_id, limit}, _from, %{conn: conn} = state) do
    statement =
      "SELECT id, sender, content, timestamp FROM messages WHERE room_id = ? ORDER BY timestamp DESC LIMIT ?"

    {:ok, %Xandra.Page{} = page} =
      Xandra.execute(conn, statement, [
        {"text", room_id},
        {"int", limit}
      ])

    messages =
      page
      |> Enum.map(fn %{
                       "id" => id,
                       "sender" => sender,
                       "content" => content,
                       "timestamp" => timestamp
                     } ->
        %{id: id, sender: sender, content: content, timestamp: timestamp}
      end)
      |> Enum.reverse()

    {:reply, messages, state}
  end
end
