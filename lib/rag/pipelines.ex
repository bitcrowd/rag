defmodule Rag.Pipelines do
  @moduledoc """
  This module contains RAG pipelines.
  """

  def ingest_bumblebee_text_embeddings_sqlite_vec(inputs, repo) do
    inputs
    |> Enum.map(&Rag.Loading.load_file(&1))
    |> Enum.flat_map(&Rag.Loading.chunk_text(&1))
    |> Rag.Embedding.Bumblebee.generate_embeddings_batch(:chunk, :embedding)
    |> Rag.Pipelines.SqliteVec.insert_all(repo)
  end

  def query_bumblebee_text_embeddings_sqlite_vec(query, repo) do
    %{query: query}
    |> Rag.Embedding.Bumblebee.generate_embedding(:query, :query_embedding)
    |> Rag.Pipelines.SqliteVec.query(repo, 3)
    |> Rag.Generation.Bumblebee.generate_response()
  end

  def ingest_bumblebee_text_embeddings_chroma(inputs, collection) do
    inputs
    |> Enum.map(&Rag.Loading.load_file(&1))
    |> Enum.flat_map(&Rag.Loading.chunk_text(&1))
    |> Rag.Embedding.Bumblebee.generate_embeddings_batch(:chunk, :embedding)
    |> Rag.Pipelines.Chroma.insert_all(collection)
  end

  def query_bumblebee_text_embeddings_chroma(query, collection) do
    %{query: query}
    |> Rag.Embedding.Bumblebee.generate_embedding(:query, :query_embedding)
    |> Rag.Pipelines.Chroma.query(collection, 3)
    |> Rag.Generation.Bumblebee.generate_response()
  end

  def query_openai_with_bumblebee_text_embeddings_chroma(query, collection) do
    llm =
      LangChain.ChatModels.ChatOpenAI.new!(%{
        model: "gpt-4o-mini",
        api_key: System.fetch_env!("OPENAI_API_KEY"),
        stream: false
      })

    chain = LangChain.Chains.LLMChain.new!(%{llm: llm})

    %{query: query}
    |> Rag.Embedding.Bumblebee.generate_embedding(:query, :query_embedding)
    |> Rag.Pipelines.Chroma.query(collection, 3)
    |> Rag.Generation.LangChain.generate_response(chain)
  end
end
