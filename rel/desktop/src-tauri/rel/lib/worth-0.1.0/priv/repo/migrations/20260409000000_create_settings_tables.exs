defmodule Worth.Repo.Migrations.CreateSettingsTables do
  use Ecto.Migration

  def change do
    create table(:worth_master_password) do
      add :password_hash, :string, null: false
      add :key_salt, :binary, null: false
      timestamps()
    end

    create table(:worth_settings) do
      add :key, :string, null: false
      add :encrypted_value, :binary, null: false
      add :category, :string, null: false, default: "secret"
      timestamps()
    end

    create unique_index(:worth_settings, [:key])
  end
end
