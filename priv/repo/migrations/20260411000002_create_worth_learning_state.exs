defmodule Worth.Repo.Migrations.CreateWorthLearningState do
  use Ecto.Migration

  def change do
    create table(:worth_learning_state) do
      add(:workspace_name, :string, null: false)
      add(:key, :string, null: false)
      add(:value, :map, default: %{})

      timestamps(updated_at: :updated_at)
    end

    create(index(:worth_learning_state, [:workspace_name, :key], unique: true))
  end
end
