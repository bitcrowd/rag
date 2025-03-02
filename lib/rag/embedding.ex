defmodule Rag.Embedding do
  @moduledoc """
  Functions to generate embeddings.
  """

  alias Rag.Generation

  @type embedding :: list(number())
  @type embeddings_function :: (list(String.t()), keyword() -> list(embedding()))
  @type provider :: struct()

  @doc """
  Passes a text from `ingestion` to `embeddings_function` or `provider` to generate an embedding.
  Then, puts the embedding in `ingestion`.

  ## Options

   * `text_key`: key which holds the text that is used to generate the embedding. Default: `:text`
   * `embedding_key`: key where the generated embedding is stored. Default: `:embedding`
  """
  @spec generate_embedding(map(), embeddings_function() | provider(), opts :: keyword()) :: %{
          atom() => embedding(),
          optional(any) => any
        }
  def generate_embedding(ingestion, %provider_module{} = provider, opts) do
    generate_embedding(ingestion, &provider_module.generate_embeddings(provider, &1, &2), opts)
  end

  def generate_embedding(ingestion, embeddings_function, opts) do
    opts = Keyword.validate!(opts, text_key: :text, embedding_key: :embedding)
    text_key = opts[:text_key]
    embedding_key = opts[:embedding_key]

    text = Map.fetch!(ingestion, text_key)

    metadata = %{ingestion: ingestion, opts: opts}

    :telemetry.span([:rag, :generate_embedding], metadata, fn ->
      {:ok, [embedding]} = embeddings_function.([text], [])

      ingestion = Map.put(ingestion, embedding_key, embedding)

      {ingestion, %{metadata | ingestion: ingestion}}
    end)
  end

  @doc """
  Passes `generation.query` to `embeddings_function` or `provider` to generate an embedding.
  Then, puts the embedding in `generation.query_embedding`.
  """
  @spec generate_embedding(Generation.t(), embeddings_function() | provider()) :: Generation.t()
  def generate_embedding(%Generation{halted?: true} = generation, _fn), do: generation

  def generate_embedding(%Generation{} = generation, %provider_module{} = provider) do
    generate_embedding(generation, &provider_module.generate_embeddings(provider, &1, &2))
  end

  def generate_embedding(%Generation{} = generation, embeddings_function) do
    metadata = %{generation: generation}

    :telemetry.span([:rag, :generate_embedding], metadata, fn ->
      generation =
        case embeddings_function.([generation.query], []) do
          {:ok, [embedding]} -> Generation.put_query_embedding(generation, embedding)
          {:error, error} -> generation |> Generation.add_error(error) |> Generation.halt()
        end

      {generation, %{metadata | generation: generation}}
    end)
  end

  @doc """
  Passes all values of `ingestions` at `text_key` to `embeddings_function` or `provider` to generate all embeddings in a single batch.
  Puts the embeddings in `ingestions` at `embedding_key`.

  ## Options

   * `text_key`: key which holds the text that is used to generate the embedding. Default: `:text`
   * `embedding_key`: key where the generated embedding is stored. Default: `:embedding`
  """
  @spec generate_embeddings_batch(
          list(map()),
          embeddings_function() | provider(),
          opts :: keyword()
        ) :: list(%{atom() => embedding(), optional(any) => any})
  def generate_embeddings_batch(ingestions, %provider_module{} = provider, opts) do
    generate_embeddings_batch(
      ingestions,
      &provider_module.generate_embeddings(provider, &1, &2),
      opts
    )
  end

  def generate_embeddings_batch(ingestions, embeddings_function, opts) do
    opts = Keyword.validate!(opts, text_key: :text, embedding_key: :embedding)
    text_key = opts[:text_key]
    embedding_key = opts[:embedding_key]

    texts = Enum.map(ingestions, &Map.fetch!(&1, text_key))

    metadata = %{ingestions: ingestions, opts: opts}

    :telemetry.span([:rag, :generate_embeddings_batch], metadata, fn ->
      {:ok, embeddings} = embeddings_function.(texts, [])

      ingestions =
        Enum.zip_with(ingestions, embeddings, fn ingestion, embedding ->
          Map.put(ingestion, embedding_key, embedding)
        end)

      {ingestions, %{metadata | ingestions: ingestions}}
    end)
  end
end
