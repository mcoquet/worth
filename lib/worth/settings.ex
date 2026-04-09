defmodule Worth.Settings do
  @moduledoc """
  Service facade for encrypted settings.

  Secrets are stored in PostgreSQL encrypted via Cloak/AES-GCM. The cipher
  key is derived from a user-chosen master password. The vault starts locked
  on boot; call `unlock/1` (or `setup_password/1` on first run) before
  reading or writing secrets.
  """

  import Ecto.Query

  alias Worth.Repo
  alias Worth.Settings.{MasterPassword, Setting}
  alias Worth.Vault
  alias Worth.Vault.Password

  # ── Password management ─────────────────────────────────────────

  @doc "True if a master password has been set."
  def has_password? do
    Repo.exists?(MasterPassword)
  end

  @doc "True if the vault is locked (no cipher key loaded)."
  def locked? do
    Vault.locked?()
  end

  @doc """
  First-time setup: hash the password, generate a key-derivation salt,
  store both in the DB, and unlock the vault.
  """
  def setup_password(password) when is_binary(password) and password != "" do
    if has_password?() do
      {:error, :already_set}
    else
      salt = Password.generate_salt()
      hash = Password.hash_password(password)

      case Repo.insert(MasterPassword.changeset(%MasterPassword{}, %{
        password_hash: hash,
        key_salt: salt
      })) do
        {:ok, _record} ->
          derived = Password.derive_key(password, salt)
          Vault.configure_key(derived)
          :ok

        {:error, changeset} ->
          {:error, changeset}
      end
    end
  end

  def setup_password(_), do: {:error, :empty_password}

  @doc """
  Unlock the vault with the master password. Verifies the password
  against the stored hash, derives the key, and configures the Vault.
  """
  def unlock(password) when is_binary(password) do
    case Repo.one(from(mp in MasterPassword, limit: 1)) do
      nil ->
        {:error, :no_password_set}

      %MasterPassword{password_hash: hash, key_salt: salt} ->
        if Password.verify_password(password, hash) do
          derived = Password.derive_key(password, salt)
          Vault.configure_key(derived)
          :ok
        else
          {:error, :invalid_password}
        end
    end
  end

  @doc """
  Change the master password. Requires the current password for verification.
  Re-encrypts all existing settings with the new key.
  """
  def change_password(current_password, new_password)
      when is_binary(current_password) and is_binary(new_password) and new_password != "" do
    case Repo.one(from(mp in MasterPassword, limit: 1)) do
      nil ->
        {:error, :no_password_set}

      %MasterPassword{password_hash: hash} = record ->
        if Password.verify_password(current_password, hash) do
          # Decrypt all settings with the current key first
          all_settings =
            Repo.all(Setting)
            |> Enum.map(fn s -> {s.key, s.encrypted_value, s.category} end)

          # Generate new salt and derive new key
          new_salt = Password.generate_salt()
          new_hash = Password.hash_password(new_password)
          new_key = Password.derive_key(new_password, new_salt)

          # Update the master password record
          record
          |> MasterPassword.changeset(%{password_hash: new_hash, key_salt: new_salt})
          |> Repo.update!()

          # Configure vault with the new key
          Vault.configure_key(new_key)

          # Re-encrypt all settings with the new key
          for {key, value, category} <- all_settings do
            case Repo.get_by(Setting, key: key) do
              nil -> :ok
              setting ->
                setting
                |> Setting.changeset(%{encrypted_value: value, category: category})
                |> Repo.update!()
            end
          end

          :ok
        else
          {:error, :invalid_password}
        end
    end
  end

  def change_password(_, _), do: {:error, :empty_password}

  @doc "Lock the vault, clearing the cipher key from memory."
  def lock do
    Vault.lock()
  end

  # ── Settings CRUD ───────────────────────────────────────────────

  @doc "Get a decrypted setting value by key. Returns nil if not found or vault locked."
  def get(key) when is_binary(key) do
    case Repo.get_by(Setting, key: key) do
      nil -> nil
      %Setting{encrypted_value: value} -> value
    end
  end

  @doc "Store (upsert) an encrypted setting."
  def put(key, value, category \\ "secret") when is_binary(key) and is_binary(value) do
    case Repo.get_by(Setting, key: key) do
      nil ->
        %Setting{}
        |> Setting.changeset(%{key: key, encrypted_value: value, category: category})
        |> Repo.insert()

      existing ->
        existing
        |> Setting.changeset(%{encrypted_value: value, category: category})
        |> Repo.update()
    end
  end

  @doc "Delete a setting by key."
  def delete(key) when is_binary(key) do
    case Repo.get_by(Setting, key: key) do
      nil -> {:error, :not_found}
      setting -> Repo.delete(setting)
    end
  end

  @doc "List all settings in a category. Values are decrypted."
  def all_by_category(category) when is_binary(category) do
    from(s in Setting, where: s.category == ^category, order_by: s.key)
    |> Repo.all()
  end

  @doc "List all setting keys (no decryption needed for keys)."
  def list_keys do
    from(s in Setting, select: {s.key, s.category}, order_by: s.key)
    |> Repo.all()
  end

  # ── Migration helper ────────────────────────────────────────────

  @doc """
  Import plaintext secrets from Worth.Config.Store into the encrypted store.
  Called once after first unlock to migrate existing secrets.
  """
  def import_from_config_store do
    disk = Worth.Config.Store.load()

    case Map.get(disk, :secrets) do
      secrets when is_map(secrets) and map_size(secrets) > 0 ->
        Enum.each(secrets, fn {key, value} when is_binary(key) and is_binary(value) ->
          put(key, value, "secret")
        end)

        {:ok, map_size(secrets)}

      _ ->
        {:ok, 0}
    end
  end
end
