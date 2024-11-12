defmodule Rag.Pipelines.SqliteVec.Migrations do
  use Ecto.Migration

  def up() do
    create table(:chunks) do
      add(:document, :text)
      add(:source, :text)
      add(:chunk, :text)
      add(:embedding, :binary)

      timestamps()
    end
  end

  def down() do
    drop(table(:chunks))
  end
end
