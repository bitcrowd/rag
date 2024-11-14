defmodule Rag.Pipelines.Pgvector.VectorStore do
  import Ecto.Query
  import Pgvector.Ecto.Query

  def insert(rag_state, repo) do
    rag_state
    |> Rag.Pipelines.Pgvector.Chunk.changeset()
    |> repo.insert()
  end

  def insert_all(rag_state_list, repo) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    chunks =
      rag_state_list
      |> Enum.map(&Map.take(&1, [:document, :source, :chunk, :embedding]))
      |> Enum.map(&Map.put_new(&1, :inserted_at, now))
      |> Enum.map(&Map.put_new(&1, :updated_at, now))

    repo.insert_all(Rag.Pipelines.Pgvector.Chunk, chunks)
  end

  @type embedding :: list(number())
  @spec query(%{query_embedding: embedding()}, Ecto.Repo.t(), integer()) :: %{
          query_results: list(%{document: binary(), source: binary()})
        }
  def query(rag_state, repo, limit) do
    %{query_embedding: query_embedding} = rag_state

    results =
      repo.all(
        from(c in Rag.Pipelines.Pgvector.Chunk,
          order_by: l2_distance(c.embedding, ^Pgvector.new(query_embedding)),
          limit: ^limit
        )
      )

    Map.put(rag_state, :query_results, results)
  end
end
