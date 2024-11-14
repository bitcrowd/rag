defmodule Rag.Pipelines.Chroma.VectorStore do
  def insert(rag_state, collection) do
    batch = to_chroma_batch([rag_state])

    Chroma.Collection.add(collection, batch)
  end

  def insert_all(rag_state_list, collection) do
    batch = to_chroma_batch(rag_state_list)

    Chroma.Collection.add(collection, batch)
  end

  @type embedding :: list(number())
  @spec query(%{query_embedding: embedding()}, Ecto.Repo.t(), integer()) :: %{
          query_results: list(%{document: binary(), source: binary()})
        }
  def query(rag_state, collection, limit) do
    %{query_embedding: query_embedding} = rag_state

    {:ok, results} =
      Chroma.Collection.query(collection,
        results: limit,
        query_embeddings: [query_embedding]
      )

    {documents, sources} = {results["documents"], results["ids"]}

    results =
      Enum.zip(documents, sources)
      |> Enum.map(fn {document, source} -> %{document: document, source: source} end)

    Map.put(rag_state, :query_results, results)
  end

  def get_or_create(name, opts \\ %{}), do: Chroma.Collection.get_or_create(name, opts)
  def delete(collection), do: Chroma.Collection.delete(collection)

  defp to_chroma_batch(rag_state_list) do
    for %{document: document, source: source, chunk: chunk, embedding: embedding} <-
          rag_state_list,
        reduce: %{documents: [], ids: [], sources: [], chunks: [], embeddings: []} do
      %{documents: documents, sources: sources, chunks: chunks, embeddings: embeddings} ->
        %{
          documents: [document | documents],
          sources: [source | sources],
          ids: [source | sources],
          chunks: [chunk | chunks],
          embeddings: [embedding | embeddings]
        }
    end
    |> Map.drop([:sources, :chunks])
  end
end
