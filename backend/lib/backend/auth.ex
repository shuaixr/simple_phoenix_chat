defmodule Backend.Auth do
  use Joken.Config

  def generate_token(user_id) do
    signer =
      Joken.Signer.create("HS256", Application.get_env(:chat, :secret_key_base, "test_key"))

    claims = %{
      "user_id" => user_id,
      "exp" => DateTime.utc_now() |> DateTime.add(7 * 24 * 60 * 60) |> DateTime.to_unix()
    }

    generate_and_sign(claims, signer)
  end

  def verify_token(token) do
    signer =
      Joken.Signer.create("HS256", Application.get_env(:chat, :secret_key_base, "test_key"))

    verify_and_validate(token, signer)
  end
end
