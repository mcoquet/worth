defmodule Worth.Vault do
  @moduledoc """
  Cloak Vault for encrypting secrets at rest.

  The cipher key is derived from a user-chosen master password via PBKDF2.
  The Vault starts "locked" (no ciphers configured) and must be unlocked
  by calling `Worth.Settings.unlock/1` with the correct password, which
  configures the AES-GCM cipher at runtime.
  """

  use Cloak.Vault, otp_app: :worth

  @doc """
  Configure the vault with a derived key. Called by Worth.Settings.unlock/1.
  """
  def configure_key(derived_key) when byte_size(derived_key) == 32 do
    config = [
      ciphers: [
        default: {Cloak.Ciphers.AES.GCM, tag: "AES.GCM.V1", key: derived_key}
      ]
    ]

    GenServer.call(__MODULE__, {:configure, config})
  end

  @doc "Returns true if no ciphers are configured (vault is locked)."
  def locked? do
    GenServer.call(__MODULE__, :locked?)
  end

  @doc "Remove all ciphers, locking the vault."
  def lock do
    GenServer.call(__MODULE__, :lock)
  end

  @impl GenServer
  def handle_call({:configure, new_config}, _from, config) do
    merged = Keyword.merge(config, new_config)
    Cloak.Vault.save_config(:"Elixir.Worth.Vault.Config", merged)
    {:reply, :ok, merged}
  end

  def handle_call(:locked?, _from, config) do
    ciphers = Keyword.get(config, :ciphers, [])
    {:reply, ciphers == [], config}
  end

  def handle_call(:lock, _from, config) do
    locked = Keyword.put(config, :ciphers, [])
    Cloak.Vault.save_config(:"Elixir.Worth.Vault.Config", locked)
    {:reply, :ok, locked}
  end

  def handle_call(msg, from, config) do
    super(msg, from, config)
  end
end
