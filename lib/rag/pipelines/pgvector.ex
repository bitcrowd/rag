defmodule Rag.Pipelines.Pgvector do
  import Ecto.Query
  import Pgvector.Ecto.Query

  def insert(input, repo) do
    input
    |> Rag.Pipelines.Pgvector.Chunk.changeset()
    |> repo.insert()
  end

  def insert_all(inputs, repo) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    inputs =
      inputs
      |> Enum.map(&Map.take(&1, [:document, :source, :chunk, :embedding]))
      |> Enum.map(&Map.put_new(&1, :inserted_at, now))
      |> Enum.map(&Map.put_new(&1, :updated_at, now))

    repo.insert_all(Rag.Pipelines.Pgvector.Chunk, inputs)
  end

  @spec query(%{query_embedding: Nx.Tensor.t()}, Ecto.Repo.t(), integer()) :: %{
          query_results: list(%{document: binary(), source: binary()})
        }
  def query(%{query_embedding: query_embedding} = input, repo, limit) do
    results =
      repo.all(
        from(c in Rag.Pipelines.Pgvector.Chunk,
          order_by: l2_distance(c.embedding, ^Pgvector.new(query_embedding)),
          limit: ^limit
        )
      )

    Map.put(input, :query_results, results)
  end
end
