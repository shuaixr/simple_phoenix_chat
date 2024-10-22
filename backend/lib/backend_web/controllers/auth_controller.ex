defmodule BackendWeb.AuthController do
  use BackendWeb, :controller

  def register(conn, %{"username" => username, "password" => password}) do
    case Backend.Repo.create_user(username, password) do
      {:ok, user} ->
        {:ok, token, _claims} = Backend.Auth.generate_token(user.id)
        json(conn, %{token: token, user: %{id: user.id, username: user.username}})

      {:error, :username_taken} ->
        conn
        |> put_status(:conflict)
        |> json(%{error: "Username already taken"})
    end
  end

  def login(conn, %{"username" => username, "password" => password}) do
    with {:ok, user} <- Backend.Repo.get_user_by_username(username),
         true <- Backend.User.verify_password(password, user.password_hash),
         {:ok, token, _claims} <- Backend.Auth.generate_token(user.id) do
      json(conn, %{token: token, user: %{id: user.id, username: user.username}})
    else
      _ ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Invalid username or password"})
    end
  end
end
