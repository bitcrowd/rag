defmodule Rag.Embedding.Nx do
  @moduledoc """
  Functions to generate embeddings using `Nx.Serving.batched_run/2`. 
  """

  alias Rag.Generation

  @doc """
  Passes the value of `ingestion` at `text_key` to `serving` to generate an embedding.
  Then, puts the embedding in `ingestion` at `embedding_key`.
  """
  @spec generate_embedding(
          map(),
          Nx.Serving.t(),
          text_key :: atom(),
          embedding_key :: atom()
        ) :: map()
  def generate_embedding(ingestion, serving \\ Rag.EmbeddingServing, text_key, embedding_key) do
    text = Map.fetch!(ingestion, text_key)

    metadata = %{serving: serving, ingestion: ingestion}

    :telemetry.span([:rag, :generate_embedding], metadata, fn ->
      %{embedding: embedding} = Nx.Serving.batched_run(serving, text)

      ingestion = Map.put(ingestion, embedding_key, Nx.to_list(embedding))
      {ingestion, %{metadata | ingestion: ingestion}}
    end)
  end

  @doc """
  Passes `generation.query` to `serving` to generate an embedding.
  Then, puts the embedding in `generation.query_embedding`.
  """
  @spec generate_embedding(Generation.t(), Nx.Serving.t()) :: Generation.t()
  def generate_embedding(%Generation{} = generation, serving \\ Rag.EmbeddingServing) do
    text = generation.query

    metadata = %{serving: serving, generation: generation}

    :telemetry.span([:rag, :generate_embedding], metadata, fn ->
      %{embedding: embedding} = Nx.Serving.batched_run(serving, text)

      generation = %{generation | query_embedding: Nx.to_list(embedding)}

      {generation, %{metadata | generation: generation}}
    end)
  end

  @doc """
  Passes all values of `ingestions` at `text_key` to `serving` to generate all embeddings in a single batch.
  Puts the embeddings in `ingestions` at `embedding_key`.
  """
  @spec generate_embeddings_batch(
          list(map()),
          Nx.Serving.t(),
          text_key :: atom(),
          embedding_key :: atom()
        ) :: list(map())
  def generate_embeddings_batch(
        ingestions,
        serving \\ Rag.EmbeddingServing,
        text_key,
        embedding_key
      )
      when is_list(ingestions) do
    texts = Enum.map(ingestions, &Map.fetch!(&1, text_key))

    metadata = %{serving: serving, ingestions: ingestions}

    :telemetry.span([:rag, :generate_embeddings_batch], metadata, fn ->
      embeddings = Nx.Serving.batched_run(serving, texts)

      ingestions =
        Enum.zip_with(ingestions, embeddings, fn ingestion, embedding ->
          Map.put(ingestion, embedding_key, Nx.to_list(embedding.embedding))
        end)

      {ingestions, %{metadata | ingestions: ingestions}}
    end)
  end
end
