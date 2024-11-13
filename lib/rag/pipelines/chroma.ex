defmodule Rag.Pipelines.Chroma do
  @moduledoc """
  This module contains RAG pipelines with chroma as vector store.
  """
  def ingest_with_bumblebee_text_embeddings(inputs, collection) do
    inputs
    |> Enum.map(&Rag.Loading.load_file(&1))
    |> Enum.flat_map(&Rag.Loading.chunk_text(&1))
    |> Rag.Embedding.Bumblebee.generate_embeddings_batch(:chunk, :embedding)
    |> Rag.Pipelines.Chroma.VectorStore.insert_all(collection)
  end

  def query_with_bumblebee_text_embeddings(query, collection) do
    %{query: query}
    |> Rag.Embedding.Bumblebee.generate_embedding(:query, :query_embedding)
    |> Rag.Pipelines.Chroma.VectorStore.query(collection, 3)
    |> Rag.Generation.Bumblebee.generate_response()
  end

  def query_openai_with_bumblebee_text_embeddings(query, collection) do
    llm =
      LangChain.ChatModels.ChatOpenAI.new!(%{
        model: "gpt-4o-mini",
        api_key: System.fetch_env!("OPENAI_API_KEY"),
        stream: false
      })

    chain = LangChain.Chains.LLMChain.new!(%{llm: llm})

    %{query: query}
    |> Rag.Embedding.Bumblebee.generate_embedding(:query, :query_embedding)
    |> Rag.Pipelines.Chroma.VectorStore.query(collection, 3)
    |> Rag.Generation.LangChain.generate_response(chain)
  end
end
