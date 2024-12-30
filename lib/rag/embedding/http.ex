defmodule Rag.Embedding.Http do
  @moduledoc """
  Functions to generate embeddings using a HTTP API.
  """

  @doc """
  Passes a text from `ingestion` to the HTTP API specified by `params` to generate an embedding.
  Then, puts the embedding in `ingestion`.
  """
  @type embedding :: list(number())
  @spec generate_embedding(map(), params :: keyword(), opts :: keyword()) :: %{
          atom() => embedding(),
          optional(any) => any
        }
  def generate_embedding(ingestion, params, opts) do
    {url, params} = Keyword.pop!(params, :url)
    {input_key, params} = Keyword.pop!(params, :input_key)
    {access_embedding_function, params} = Keyword.pop!(params, :access_embedding_function)

    text_key = Keyword.get(opts, :text_key, :text)
    embedding_key = Keyword.get(opts, :embedding_key, :embedding)

    texts = Map.fetch!(ingestion, text_key) |> List.wrap()

    params = put_in(params, [:json, input_key], texts)

    metadata = %{ingestion: ingestion, url: url, params: params, opts: opts}

    :telemetry.span([:rag, :generate_embedding], metadata, fn ->
      response = Req.post!(url, params)

      [embedding] = access_embedding_function.(response.body)

      ingestion = Map.put(ingestion, embedding_key, embedding)
      {ingestion, %{metadata | ingestion: ingestion}}
    end)
  end

  @doc """
  Passes `generation.query` to the Http API to generate an embedding.
  Then, puts the embedding in `generation.query_embedding`.
  """
  @spec generate_embedding(Generation.t(), params :: keyword(), opts :: keyword()) ::
          Generation.t()
  def generate_embedding(%Rag.Generation{} = generation, params),
    do: generate_embedding(generation, params, text_key: :query, embedding_key: :query_embedding)

  @doc """
  Passes all values of `ingestions` at `text_key` to the Http API to generate all embeddings in a single batch.
  Puts the embeddings in `ingestions` at `embedding_key`.
  """
  @spec generate_embeddings_batch(list(map()), params :: keyword(), opts :: keyword()) ::
          list(%{atom() => embedding(), optional(any) => any})
  def generate_embeddings_batch(ingestions, params, opts) do
    {url, params} = Keyword.pop!(params, :url)
    {input_key, params} = Keyword.pop!(params, :input_key)
    {access_embedding_function, params} = Keyword.pop!(params, :access_embedding_function)

    text_key = Keyword.get(opts, :text_key, :text)
    embedding_key = Keyword.get(opts, :embedding_key, :embedding)

    texts = Enum.map(ingestions, &Map.fetch!(&1, text_key))

    params = put_in(params, [:json, input_key], texts)

    metadata = %{ingestions: ingestions, url: url, params: params, opts: opts}

    :telemetry.span([:rag, :generate_embeddings_batch], metadata, fn ->
      response = Req.post!(url, params)

      embeddings = access_embedding_function.(response.body)

      ingestions =
        Enum.zip_with(ingestions, embeddings, fn ingestion, embedding ->
          Map.put(ingestion, embedding_key, embedding)
        end)

      {ingestions, %{metadata | ingestions: ingestions}}
    end)
  end
end
