defmodule Worth.Settings.Setting do
  @moduledoc """
  Ecto schema for encrypted settings.

  Each row stores a single key-value pair. The value is encrypted at rest
  via Cloak/AES-GCM through `Worth.Vault`. Settings are grouped by
  `category` ("secret", "preference", etc.).
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "worth_settings" do
    field :key, :string
    field :encrypted_value, Worth.Encrypted.Binary
    field :category, :string, default: "secret"
    timestamps()
  end

  def changeset(setting, attrs) do
    setting
    |> cast(attrs, [:key, :encrypted_value, :category])
    |> validate_required([:key, :encrypted_value])
    |> unique_constraint(:key)
  end
end
