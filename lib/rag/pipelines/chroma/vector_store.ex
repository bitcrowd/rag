defmodule Rag.Pipelines.Chroma.VectorStore do
  def insert(input, collection) do
    batch = to_chroma_batch([input])

    Chroma.Collection.add(collection, batch)
  end

  def insert_all(inputs, collection) do
    batch = to_chroma_batch(inputs)

    Chroma.Collection.add(collection, batch)
  end

  @type embedding :: list(number())
  @spec query(%{query_embedding: embedding()}, Ecto.Repo.t(), integer()) :: %{
          query_results: list(%{document: binary(), source: binary()})
        }
  def query(%{query_embedding: query_embedding} = input, collection, limit) do
    {:ok, results} =
      Chroma.Collection.query(collection,
        results: limit,
        query_embeddings: [query_embedding]
      )

    {documents, sources} = {results["documents"], results["ids"]}

    results =
      Enum.zip(documents, sources)
      |> Enum.map(fn {document, source} -> %{document: document, source: source} end)

    Map.put(input, :query_results, results)
  end

  def get_or_create(name, opts \\ %{}), do: Chroma.Collection.get_or_create(name, opts)
  def delete(collection), do: Chroma.Collection.delete(collection)

  defp to_chroma_batch(inputs) do
    for %{document: document, source: source, chunk: chunk, embedding: embedding} <- inputs,
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
