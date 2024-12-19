defmodule Rag.Embedding.OpenAI do
  @moduledoc """
  Functions to generate embeddings using the OpenAI API.
  """

  @embeddings_url "https://api.openai.com/v1/embeddings"

  @doc """
  Passes the value of `ingestion` at `text_key` to the OpenAI API to generate an embedding.
  Then, puts the embedding in `ingestion` at `embedding_key`.
  """
  @type embedding :: list(number())
  @spec generate_embedding(
          map(),
          %{model: String.t(), api_key: String.t()},
          text_key :: atom(),
          embedding_key :: atom()
        ) :: %{
          atom() => embedding(),
          optional(any) => any
        }
  def generate_embedding(ingestion, openai_params, text_key, embedding_key) do
    text = Map.fetch!(ingestion, text_key)

    %{model: model, api_key: api_key} = openai_params

    metadata = %{embeddings_url: @embeddings_url, model: model, ingestion: ingestion}

    :telemetry.span([:rag, :generate_embedding], metadata, fn ->
      [result] =
        Req.post!(@embeddings_url,
          auth: {:bearer, api_key},
          json: %{model: model, input: text}
        ).body["data"]

      embedding = result["embedding"]

      ingestion = Map.put(ingestion, embedding_key, embedding)
      {ingestion, %{metadata | ingestion: ingestion}}
    end)
  end

  @doc """
  Passes `generation.query` to the OpenAI API to generate an embedding.
  Then, puts the embedding in `generation.query_embedding`.
  """
  @spec generate_embedding(Generation.t(), %{model: String.t(), api_key: String.t()}) ::
          Generation.t()
  def generate_embedding(generation, openai_params) do
    text = generation.query

    %{model: model, api_key: api_key} = openai_params

    metadata = %{embeddings_url: @embeddings_url, model: model, generation: generation}

    :telemetry.span([:rag, :generate_embedding], metadata, fn ->
      [result] =
        Req.post!(@embeddings_url,
          auth: {:bearer, api_key},
          json: %{model: model, input: text}
        ).body["data"]

      embedding = result["embedding"]

      generation = %{generation | query_embedding: embedding}

      {generation, %{metadata | generation: generation}}
    end)
  end

  @doc """
  Passes all values of `ingestions` at `text_key` to the OpenAI API to generate all embeddings in a single batch.
  Puts the embeddings in `ingestions` at `embedding_key`.
  """
  @spec generate_embeddings_batch(
          list(map()),
          %{model: String.t(), api_key: String.t()},
          text_key :: atom(),
          embedding_key :: atom()
        ) :: list(%{atom() => embedding(), optional(any) => any})
  def generate_embeddings_batch(
        ingestions,
        openai_params,
        text_key,
        embedding_key
      ) do
    texts = Enum.map(ingestions, &Map.fetch!(&1, text_key))

    %{model: model, api_key: api_key} = openai_params

    metadata = %{embeddings_url: @embeddings_url, model: model, ingestions: ingestions}

    :telemetry.span([:rag, :generate_embeddings_batch], metadata, fn ->
      results =
        Req.post!(@embeddings_url,
          auth: {:bearer, api_key},
          json: %{model: model, input: texts}
        ).body["data"]

      embeddings = Enum.map(results, &Map.fetch!(&1, "embedding"))

      ingestions =
        Enum.zip_with(ingestions, embeddings, fn ingestion, embedding ->
          Map.put(ingestion, embedding_key, embedding)
        end)

      {ingestions, %{metadata | ingestions: ingestions}}
    end)
  end
end
