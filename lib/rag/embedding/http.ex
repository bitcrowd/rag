defmodule Rag.Embedding.Http do
  @moduledoc """
  Implementation of `Rag.Embedding.Adapter` using HTTP.
  """

  @behaviour Rag.Embedding.Adapter

  alias Rag.{Embedding, Generation}
  alias Rag.Ai
  alias Rag.Ai.Http.EmbeddingParams

  @type embedding :: list(number())

  @doc """
  Passes a text from `ingestion` to the HTTP API specified by `params` to generate an embedding.
  Then, puts the embedding in `ingestion`.

  ## Options

   * `text_key`: key which holds the text that is used to generate the embedding. Default: `:text`
   * `embedding_key`: key where the generated embedding is stored. Default: `:embedding`
  """
  @impl Rag.Embedding.Adapter
  @spec generate_embedding(map(), EmbeddingParams.t(), opts :: keyword()) :: %{
          atom() => embedding(),
          optional(any) => any
        }
  def generate_embedding(ingestion, params, opts),
    do: Embedding.generate_embedding(ingestion, params, &Ai.Http.generate_embedding/2, opts)

  @doc """
  Passes `generation.query` to the HTTP API specified by `params` to generate an embedding.
  Then, puts the embedding in `generation.query_embedding`.
  """
  @impl Rag.Embedding.Adapter
  @spec generate_embedding(Generation.t(), EmbeddingParams.t()) :: Generation.t()
  def generate_embedding(%Generation{} = generation, params),
    do: Embedding.generate_embedding(generation, params, &Ai.Http.generate_embedding/2)

  @doc """
  Passes all values of `ingestions` at `text_key` to the HTTP API specified by `params` to generate all embeddings in a single batch.
  Puts the embeddings in `ingestions` at `embedding_key`.

  ## Options

   * `text_key`: key which holds the text that is used to generate the embedding. Default: `:text`
   * `embedding_key`: key where the generated embedding is stored. Default: `:embedding`
  """
  @impl Rag.Embedding.Adapter
  @spec generate_embeddings_batch(list(map()), EmbeddingParams.t(), opts :: keyword()) ::
          list(%{atom() => embedding(), optional(any) => any})
  def generate_embeddings_batch(ingestions, params, opts) when is_list(ingestions),
    do:
      Embedding.generate_embeddings_batch(
        ingestions,
        params,
        &Ai.Http.generate_embeddings_batch/2,
        opts
      )
end
