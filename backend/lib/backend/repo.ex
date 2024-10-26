defmodule Backend.Repo do
  use GenServer

  @moduledoc """
  CREATE TABLE users (
      id uuid PRIMARY KEY,
      username text,
      password_hash text,
      created_at timestamp
  );

  CREATE TABLE users_by_username (
      username text PRIMARY KEY,
      user_id uuid
  );
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

  def create_user(username, password) do
    GenServer.call(__MODULE__, {:create_user, username, password})
  end

  def get_user_by_username(username) do
    GenServer.call(__MODULE__, {:get_user_by_username, username})
  end

  def get_user_by_id(user_id) do
    GenServer.call(__MODULE__, {:get_user_by_id, user_id})
  end

  def insert_message(id, room_id, sender_id, content) do
    GenServer.call(__MODULE__, {:insert_message, id, room_id, sender_id, content})
  end

  def get_latest_messages(room_id, limit \\ 10) do
    GenServer.call(__MODULE__, {:get_latest_messages, room_id, limit})
  end

  def update_password(user_id, old_password, new_password) do
    GenServer.call(__MODULE__, {:update_password, user_id, old_password, new_password})
  end

  def handle_call({:create_user, username, password}, _from, %{conn: conn} = state) do
    {:ok, user} = Backend.User.create(username, password)

    case Xandra.execute(conn, "SELECT user_id FROM users_by_username WHERE username = ?", [
           {"text", username}
         ]) do
      {:ok, page} ->
        # check exist
        if Enum.empty?(page) do
          {:ok, _} =
            Xandra.execute(
              conn,
              "INSERT INTO users (id, username, password_hash, created_at) VALUES (?, ?, ?, toTimestamp(now()))",
              [{"uuid", user.id}, {"text", username}, {"text", user.password_hash}]
            )

          {:ok, _} =
            Xandra.execute(
              conn,
              "INSERT INTO users_by_username (username, user_id) VALUES (?, ?)",
              [{"text", username}, {"uuid", user.id}]
            )

          {:reply, {:ok, user}, state}
        else
          {:reply, {:error, :username_taken}, state}
        end

      _ ->
        {:reply, {:error, :unknow}, state}
    end
  end

  def handle_call({:get_user_by_username, username}, _from, %{conn: conn} = state) do
    case Xandra.execute(conn, "SELECT user_id FROM users_by_username WHERE username = ?", [
           {"text", username}
         ]) do
      {:ok, %Xandra.Page{} = page} ->
        case Enum.at(page, 0) do
          %{"user_id" => user_id} ->
            case get_user_by_id(conn, user_id) do
              {:ok, user} ->
                {:reply, {:ok, user}, state}

              error ->
                {:reply, error, state}
            end

          _ ->
            {:reply, {:error, :user_not_found}, state}
        end

      _ ->
        {:reply, {:error, :user_not_found}, state}
    end
  end

  def handle_call({:get_user_by_id, user_id}, _from, %{conn: conn} = state) do
    case get_user_by_id(conn, user_id) do
      {:ok, user} ->
        {:reply, {:ok, user}, state}

      error ->
        {:reply, error, state}
    end
  end

  def handle_call(
        {:insert_message, id, room_id, sender_id, content},
        _from,
        %{conn: conn} = state
      ) do
    statement =
      "INSERT INTO messages (id, room_id, sender_id, content, timestamp) VALUES (?, ?, ?, ?, toTimestamp(now()))"

    {:ok, _} =
      Xandra.execute(conn, statement, [
        {"uuid", id},
        {"text", room_id},
        {"uuid", sender_id},
        {"text", content}
      ])

    {:reply, :ok, state}
  end

  def handle_call({:get_latest_messages, room_id, limit}, _from, %{conn: conn} = state) do
    statement =
      "SELECT id, sender_id, content, timestamp FROM messages WHERE room_id = ? ORDER BY timestamp DESC LIMIT ?"

    {:ok, %Xandra.Page{} = page} =
      Xandra.execute(conn, statement, [
        {"text", room_id},
        {"int", limit}
      ])

    messages =
      page
      |> Enum.map(fn %{
                       "id" => id,
                       "sender_id" => sender_id,
                       "content" => content,
                       "timestamp" => timestamp
                     } ->
        # get sender info
        case get_user_by_id(conn, sender_id) do
          {:ok, user} ->
            %{
              id: id,
              sender_id: sender_id,
              sender: user.username,
              content: content,
              timestamp: timestamp
            }

          _ ->
            %{
              id: id,
              sender_id: sender_id,
              sender: "Unknown",
              content: content,
              timestamp: timestamp
            }
        end
      end)
      |> Enum.reverse()

    {:reply, messages, state}
  end

  def handle_call(
        {:update_password, user_id, old_password, new_password},
        _from,
        %{conn: conn} = state
      ) do
    case get_user_by_id(conn, user_id) do
      {:ok, user} ->
        if Backend.User.verify_password(old_password, user.password_hash) do
          new_password_hash = Backend.User.get_password_hash(new_password)
          statement = "UPDATE users SET password_hash = ? WHERE id = ?"

          case Xandra.execute(conn, statement, [{"text", new_password_hash}, {"uuid", user_id}]) do
            {:ok, _} ->
              {:reply, :ok, state}

            error ->
              {:reply, error, state}
          end
        else
          {:reply, {:error, :invalid_password}, state}
        end

      error ->
        {:reply, error, state}
    end
  end

  defp get_user_by_id(conn, user_id) do
    IO.inspect(user_id)

    case Xandra.execute(conn, "SELECT * FROM users WHERE id = ?", [{"uuid", user_id}]) do
      {:ok, %Xandra.Page{} = user_page} ->
        case Enum.at(user_page, 0) do
          %{"username" => username, "id" => id, "password_hash" => password_hash} ->
            {:ok, %Backend.User{id: id, username: username, password_hash: password_hash}}

          _ ->
            {:error, :user_not_found}
        end

      _ ->
        {:error, :user_not_found}
    end
  end
end
