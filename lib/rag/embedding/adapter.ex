defmodule Rag.Embedding.Adapter do
  @moduledoc """
  Behaviour for embedding generation.
  """

  @doc """
  Passes a text from `ingestion` to the adapter using `adapter_params` to generate an embedding.
  Then, puts the embedding in `ingestion`.

  ## Options

   * `text_key`: key which holds the text that is used to generate the embedding. Default: `:text`
   * `embedding_key`: key where the generated embedding is stored. Default: `:embedding`
  """
  @callback generate_embedding(ingestion :: map(), adapter_params :: any(), opts :: keyword()) ::
              %{
                atom() => list(number()),
                optional(any) => any
              }

  @doc """
  Passes `generation.query` to the adapter using `adapter_params` to generate an embedding.
  Then, puts the embedding in `generation.query_embedding`.
  """
  @callback generate_embedding(generation :: Rag.Generation.t(), adapter_params :: any()) ::
              Rag.Generation.t()

  @doc """
  Passes all values of `ingestions` at `text_key` to the adapter using `adapter_params` to generate all embeddings in a single batch.
  Puts the embeddings in `ingestions` at `embedding_key`.

  ## Options

   * `text_key`: key which holds the text that is used to generate the embedding. Default: `:text`
   * `embedding_key`: key where the generated embedding is stored. Default: `:embedding`
  """
  @callback generate_embeddings_batch(
              ingestions :: list(map()),
              adapter_params :: any(),
              opts :: keyword()
            ) ::
              list(%{atom() => list(number()), optional(any) => any})
end
