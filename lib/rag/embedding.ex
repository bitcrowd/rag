defmodule Rag.Embedding do
  @moduledoc """
  Common structure for working with embeddings.
  """

  alias Rag.Generation

  @type embedding :: list(number())
  @type embedding_fn :: (String.t(), params :: any() -> embedding())
  @type embedding_batch_fn :: (list(String.t()), params :: any() -> list(embedding()))

  @doc """
  Passes a text from `ingestion` to the adapter using `params` to generate an embedding.
  Then, puts the embedding in `ingestion`.

  ## Options

   * `text_key`: key which holds the text that is used to generate the embedding. Default: `:text`
   * `embedding_key`: key where the generated embedding is stored. Default: `:embedding`
  """
  @spec generate_embedding(map(), params :: any(), embedding_fn(), opts :: keyword()) :: %{
          atom() => embedding(),
          optional(any) => any
        }
  def generate_embedding(ingestion, params, embedding_fn, opts) do
    opts = Keyword.validate!(opts, text_key: :text, embedding_key: :embedding)
    text_key = opts[:text_key]
    embedding_key = opts[:embedding_key]

    text = Map.fetch!(ingestion, text_key)

    metadata = %{ingestion: ingestion, params: params, opts: opts}

    :telemetry.span([:rag, :generate_embedding], metadata, fn ->
      {:ok, embedding} = embedding_fn.(text, params)

      ingestion = Map.put(ingestion, embedding_key, embedding)

      {ingestion, %{metadata | ingestion: ingestion}}
    end)
  end

  @doc """
  Passes `generation.query` to the adapter using `params` to generate an embedding.
  Then, puts the embedding in `generation.query_embedding`.
  """
  @spec generate_embedding(Generation.t(), params :: any(), embedding_fn()) :: Generation.t()
  def generate_embedding(%Generation{halted?: true} = generation, _params, _fn), do: generation

  def generate_embedding(%Generation{} = generation, params, embedding_fn) do
    metadata = %{generation: generation, params: params}

    :telemetry.span([:rag, :generate_embedding], metadata, fn ->
      {:ok, embedding} = embedding_fn.(generation.query, params)

      generation = Generation.put_query_embedding(generation, embedding)

      {generation, %{metadata | generation: generation}}
    end)
  end

  @doc """
  Passes all values of `ingestions` at `text_key` to the adapter using `params` to generate all embeddings in a single batch.
  Puts the embeddings in `ingestions` at `embedding_key`.

  ## Options

   * `text_key`: key which holds the text that is used to generate the embedding. Default: `:text`
   * `embedding_key`: key where the generated embedding is stored. Default: `:embedding`
  """
  @spec generate_embeddings_batch(
          list(map()),
          params :: any(),
          embedding_batch_fn(),
          opts :: keyword()
        ) :: list(%{atom() => embedding(), optional(any) => any})
  def generate_embeddings_batch(ingestions, params, embedding_batch_fn, opts) do
    opts = Keyword.validate!(opts, text_key: :text, embedding_key: :embedding)
    text_key = opts[:text_key]
    embedding_key = opts[:embedding_key]

    texts = Enum.map(ingestions, &Map.fetch!(&1, text_key))

    metadata = %{ingestions: ingestions, params: params, opts: opts}

    :telemetry.span([:rag, :generate_embeddings_batch], metadata, fn ->
      {:ok, embeddings} = embedding_batch_fn.(texts, params)

      ingestions =
        Enum.zip_with(ingestions, embeddings, fn ingestion, embedding ->
          Map.put(ingestion, embedding_key, embedding)
        end)

      {ingestions, %{metadata | ingestions: ingestions}}
    end)
  end
end
