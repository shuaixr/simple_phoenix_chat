defmodule Backend.User do
  defstruct [:id, :username, :password_hash]

  def create(username, password) do
    password_hash = get_password_hash(password)
    id = UUID.uuid4()

    {:ok,
     %__MODULE__{
       id: id,
       username: username,
       password_hash: password_hash
     }}
  end

  def get_password_hash(password) do
    Bcrypt.hash_pwd_salt(password)
  end

  def verify_password(password, password_hash) do
    Bcrypt.verify_pass(password, password_hash)
  end
end
