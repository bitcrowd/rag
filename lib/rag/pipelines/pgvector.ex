defmodule Rag.Pipelines.Pgvector do
  @moduledoc """
  This module contains RAG pipelines with pgvector as vector store.
  """

  def ingest_with_bumblebee_text_embeddings(rag_state_list, repo) do
    rag_state_list
    |> Enum.map(&Rag.Loading.load_file(&1))
    |> Enum.flat_map(&Rag.Loading.chunk_text(&1))
    |> Rag.Embedding.Bumblebee.generate_embeddings_batch(:chunk, :embedding)
    |> Rag.Pipelines.Pgvector.VectorStore.insert_all(repo)
  end

  def query_with_bumblebee_text_embeddings(query, repo, opts \\ []) do
    limit = Keyword.get(opts, :limit, 3)

    %{query: query}
    |> Rag.Embedding.Bumblebee.generate_embedding(:query, :query_embedding)
    |> Rag.Pipelines.Pgvector.VectorStore.query(repo, limit)
    |> Rag.Generation.Bumblebee.generate_response()
  end
end
