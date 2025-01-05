defmodule Rag.Embedding.Http do
  @moduledoc """
  Functions to generate embeddings using an HTTP API.
  """

  alias Rag.Generation
  alias Rag.Embedding.Http.Params

  @doc """
  Passes a text from `ingestion` to the HTTP API specified by `params` to generate an embedding.
  Then, puts the embedding in `ingestion`.

  ## Options

   * `text_key`: key which holds the text that is used to generate the embedding. Default: `:text`
   * `embedding_key`: key where the generated embedding is stored. Default: `:embedding`
  """
  @type embedding :: list(number())
  @spec generate_embedding(map(), params :: Params.t(), opts :: keyword()) :: %{
          atom() => embedding(),
          optional(any) => any
        }
  def generate_embedding(ingestion, params, opts) do
    opts = Keyword.validate!(opts, text_key: :text, embedding_key: :embedding)
    text_key = opts[:text_key]
    embedding_key = opts[:embedding_key]

    text = Map.fetch!(ingestion, text_key)

    params = Params.set_input(params, text)

    metadata = %{ingestion: ingestion, params: params, opts: opts}

    :telemetry.span([:rag, :generate_embedding], metadata, fn ->
      response = Req.post!(params.url, params.req_params)

      [embedding] = get_embeddings(response, params)

      ingestion = Map.put(ingestion, embedding_key, embedding)

      {ingestion, %{metadata | ingestion: ingestion}}
    end)
  end

  @doc """
  Passes `generation.query` to the Http API to generate an embedding.
  Then, puts the embedding in `generation.query_embedding`.
  """
  @spec generate_embedding(Generation.t(), params :: Params.t()) :: Generation.t()
  def generate_embedding(%Generation{} = generation, params),
    do: generate_embedding(generation, params, text_key: :query, embedding_key: :query_embedding)

  @doc """
  Passes all values of `ingestions` at `text_key` to the HTTP API to generate all embeddings in a single batch.
  Puts the embeddings in `ingestions` at `embedding_key`.

  ## Options

   * `text_key`: key which holds the text that is used to generate the embedding. Default: `:text`
   * `embedding_key`: key where the generated embedding is stored. Default: `:embedding`
  """
  @spec generate_embeddings_batch(list(map()), params :: Params.t(), opts :: keyword()) ::
          list(%{atom() => embedding(), optional(any) => any})
  def generate_embeddings_batch(ingestions, params, opts) do
    opts = Keyword.validate!(opts, text_key: :text, embedding_key: :embedding)
    text_key = opts[:text_key]
    embedding_key = opts[:embedding_key]

    texts = Enum.map(ingestions, &Map.fetch!(&1, text_key))

    params = Params.set_input(params, texts)

    metadata = %{ingestions: ingestions, params: params, opts: opts}

    :telemetry.span([:rag, :generate_embeddings_batch], metadata, fn ->
      response = Req.post!(params.url, params.req_params)

      embeddings = get_embeddings(response, params)

      ingestions =
        Enum.zip_with(ingestions, embeddings, fn ingestion, embedding ->
          Map.put(ingestion, embedding_key, embedding)
        end)

      {ingestions, %{metadata | ingestions: ingestions}}
    end)
  end

  defp get_embeddings(response, params), do: get_in(response.body, params.access_embeddings)
end
