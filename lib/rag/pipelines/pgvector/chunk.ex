defmodule Rag.Pipelines.Pgvector.Chunk do
  use Ecto.Schema

  schema "chunks" do
    field(:document, :string)
    field(:source, :string)
    field(:chunk, :string)
    field(:embedding, Pgvector.Ecto.Vector)

    timestamps()
  end

  def changeset(chunk \\ %__MODULE__{}, attrs) do
    Ecto.Changeset.cast(chunk, attrs, [:document, :source, :chunk, :embedding])
  end
end
