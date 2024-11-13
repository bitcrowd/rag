defmodule Rag.Pipelines.SqliteVec.VectorStore do
  import Ecto.Query
  import SqliteVec.Ecto.Query

  def insert(input, repo) do
    Rag.Pipelines.SqliteVec.Chunk.changeset(input)
    |> repo.insert()
  end

  def insert_all(inputs, repo) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    inputs =
      inputs
      |> Enum.map(&Map.take(&1, [:document, :source, :chunk, :embedding]))
      |> Enum.map(&Map.put_new(&1, :inserted_at, now))
      |> Enum.map(&Map.put_new(&1, :updated_at, now))

    repo.insert_all(Rag.Pipelines.SqliteVec.Chunk, inputs)
  end

  @type embedding :: list(number())
  @spec query(%{query_embedding: embedding()}, Ecto.Repo.t(), integer()) :: %{
          query_results: list(%{document: binary(), source: binary()})
        }
  def query(%{query_embedding: query_embedding} = input, repo, limit) do
    query_vector = SqliteVec.Float32.new(query_embedding)

    results =
      repo.all(
        from(c in Rag.Pipelines.SqliteVec.Chunk,
          order_by: l2_distance(c.embedding, vec_f32(^query_vector.data)),
          limit: ^limit
        )
      )

    Map.put(input, :query_results, results)
  end
end
