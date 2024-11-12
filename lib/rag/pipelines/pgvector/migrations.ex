defmodule Rag.Pipelines.Pgvector.Migrations do
  use Ecto.Migration

  def up() do
    execute("CREATE EXTENSION IF NOT EXISTS vector")

    flush()

    create table(:chunks) do
      add(:document, :text)
      add(:source, :text)
      add(:chunk, :text)
      add(:embedding, :vector, size: 768)

      timestamps()
    end
  end

  def down() do
    drop(table(:chunks))
    execute("DROP EXTENSION vector")
  end
end
