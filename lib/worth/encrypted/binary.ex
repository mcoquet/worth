defmodule Worth.Encrypted.Binary do
  @moduledoc "Cloak.Ecto encrypted binary type backed by Worth.Vault."
  use Cloak.Ecto.Binary, vault: Worth.Vault
end
