defmodule Rag.Embedding.Nx do
  @moduledoc """
  Functions to generate embeddings using `Nx.Serving.batched_run/2`. 
  """

  alias Rag.Generation

  @doc """
  Passes the value of `ingestion` at `text_key` to `serving` to generate an embedding.
  Then, puts the embedding in `ingestion` at `embedding_key`.

  ## Options

   * `text_key`: key which holds the text that is used to generate the embedding. Default: `:text`
   * `embedding_key`: key where the generated embedding is stored. Default: `:embedding`
  """
  @type embedding :: list(number())
  @spec generate_embedding(map(), Nx.Serving.t(), opts :: keyword()) :: %{
          atom() => embedding(),
          optional(any) => any
        }
  def generate_embedding(ingestion, serving, opts) do
    opts = Keyword.validate!(opts, text_key: :text, embedding_key: :embedding)
    text_key = opts[:text_key]
    embedding_key = opts[:embedding_key]

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
  def generate_embedding(%Generation{} = generation, serving),
    do: generate_embedding(generation, serving, text_key: :query, embedding_key: :query_embedding)

  @doc """
  Passes all values of `ingestions` at `text_key` to `serving` to generate all embeddings in a single batch.
  Puts the embeddings in `ingestions` at `embedding_key`.

  ## Options

   * `text_key`: key which holds the text that is used to generate the embedding. Default: `:text`
   * `embedding_key`: key where the generated embedding is stored. Default: `:embedding`
  """
  @spec generate_embeddings_batch(list(map()), Nx.Serving.t(), opts :: keyword()) ::
          list(%{atom() => embedding(), optional(any) => any})
  def generate_embeddings_batch(ingestions, serving, opts) when is_list(ingestions) do
    opts = Keyword.validate!(opts, text_key: :text, embedding_key: :embedding)
    text_key = opts[:text_key]
    embedding_key = opts[:embedding_key]

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
