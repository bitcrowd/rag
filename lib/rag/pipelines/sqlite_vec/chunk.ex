defmodule Rag.Pipelines.SqliteVec.Chunk do
  use Ecto.Schema

  schema "chunks" do
    field(:document, :string)
    field(:source, :string)
    field(:chunk, :string)
    field(:embedding, SqliteVec.Ecto.Float32)

    timestamps()
  end

  def changeset(chunk \\ %__MODULE__{}, attrs) do
    Ecto.Changeset.cast(chunk, attrs, [:document, :source, :chunk, :embedding])
  end
end
