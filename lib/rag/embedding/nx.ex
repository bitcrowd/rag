defmodule Rag.Embedding.Nx do
  @moduledoc """
  Implementation of `Rag.Embedding.Adapter` using `Nx`.
  """

  @behaviour Rag.Embedding.Adapter

  alias Rag.{Embedding, Generation}
  alias Rag.Ai

  @type embedding :: list(number())

  @doc """
  Passes the value of `ingestion` at `text_key` to `serving` to generate an embedding.
  Then, puts the embedding in `ingestion` at `embedding_key`.

  ## Options

   * `text_key`: key which holds the text that is used to generate the embedding. Default: `:text`
   * `embedding_key`: key where the generated embedding is stored. Default: `:embedding`
  """
  @impl Rag.Embedding.Adapter
  @spec generate_embedding(map(), Nx.Serving.t(), opts :: keyword()) :: %{
          atom() => embedding(),
          optional(any) => any
        }
  def generate_embedding(ingestion, serving, opts),
    do: Embedding.generate_embedding(ingestion, serving, &Ai.Nx.generate_embedding/2, opts)

  @doc """
  Passes `generation.query` to `serving` to generate an embedding.
  Then, puts the embedding in `generation.query_embedding`.
  """
  @impl Rag.Embedding.Adapter
  def generate_embedding(%Generation{} = generation, serving),
    do: Embedding.generate_embedding(generation, serving, &Ai.Nx.generate_embedding/2)

  @doc """
  Passes all values of `ingestions` at `text_key` to `serving` to generate all embeddings in a single batch.
  Puts the embeddings in `ingestions` at `embedding_key`.

  ## Options

   * `text_key`: key which holds the text that is used to generate the embedding. Default: `:text`
   * `embedding_key`: key where the generated embedding is stored. Default: `:embedding`
  """
  @impl Rag.Embedding.Adapter
  @spec generate_embeddings_batch(list(map()), Nx.Serving.t(), opts :: keyword()) ::
          list(%{atom() => embedding(), optional(any) => any})
  def generate_embeddings_batch(ingestions, serving, opts) when is_list(ingestions),
    do:
      Embedding.generate_embeddings_batch(
        ingestions,
        serving,
        &Ai.Nx.generate_embeddings_batch/2,
        opts
      )
end
