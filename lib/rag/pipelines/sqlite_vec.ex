defmodule Rag.Pipelines.SqliteVec do
  @moduledoc """
  This module contains RAG pipelines with sqlite-vec as vector store.
  """

  def ingest_with_bumblebee_text_embeddings(inputs, repo) do
    inputs
    |> Enum.map(&Rag.Loading.load_file(&1))
    |> Enum.flat_map(&Rag.Loading.chunk_text(&1))
    |> Rag.Embedding.Bumblebee.generate_embeddings_batch(:chunk, :embedding)
    |> Rag.Pipelines.SqliteVec.VectorStore.insert_all(repo)
  end

  def query_with_bumblebee_text_embeddings(query, repo) do
    %{query: query}
    |> Rag.Embedding.Bumblebee.generate_embedding(:query, :query_embedding)
    |> Rag.Pipelines.SqliteVec.VectorStore.query(repo, 3)
    |> Rag.Generation.Bumblebee.generate_response()
  end
end
