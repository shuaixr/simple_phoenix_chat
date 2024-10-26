defmodule BackendWeb.UserController do
  use BackendWeb, :controller

  def update_password(conn, %{"old_password" => old_password, "new_password" => new_password}) do
    with authorization_header <- get_req_header(conn, "authorization"),
         [token] <- authorization_header,
         {:ok, header_user} <-
           Backend.Auth.verify_token(token),
         user_id <-
           header_user["user_id"],
         :ok <- Backend.Repo.update_password(user_id, old_password, new_password) do
      json(conn, %{message: "Password updated successfully"})
    else
      {:error, :invalid_password} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Invalid password"})

      _ ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Unauthorized"})
    end
  end
end
