defmodule Rag.Pipelines.Chroma do
  @moduledoc """
  This module contains RAG pipelines with chroma as vector store.
  """
  def ingest_with_bumblebee_text_embeddings(rag_state_list, collection) do
    rag_state_list
    |> Enum.map(&Rag.Loading.load_file(&1))
    |> Enum.flat_map(&Rag.Loading.chunk_text(&1))
    |> Rag.Embedding.Bumblebee.generate_embeddings_batch(:chunk, :embedding)
    |> Rag.Pipelines.Chroma.VectorStore.insert_all(collection)
  end

  def query_with_bumblebee_text_embeddings(query, collection, opts \\ []) do
    limit = Keyword.get(opts, :limit, 3)

    %{query: query}
    |> Rag.Embedding.Bumblebee.generate_embedding(:query, :query_embedding)
    |> Rag.Pipelines.Chroma.VectorStore.query(collection, limit)
    |> Rag.Generation.Bumblebee.generate_response()
  end

  def query_openai_with_bumblebee_text_embeddings(query, collection, opts \\ []) do
    limit = Keyword.get(opts, :limit, 3)

    llm =
      LangChain.ChatModels.ChatOpenAI.new!(%{
        model: "gpt-4o-mini",
        api_key: System.fetch_env!("OPENAI_API_KEY"),
        stream: false
      })

    chain = LangChain.Chains.LLMChain.new!(%{llm: llm})

    %{query: query}
    |> Rag.Embedding.Bumblebee.generate_embedding(:query, :query_embedding)
    |> Rag.Pipelines.Chroma.VectorStore.query(collection, limit)
    |> Rag.Generation.LangChain.generate_response(chain)
  end
end
