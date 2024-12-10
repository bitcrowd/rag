defmodule Rag.Embedding.OpenAI do
  @moduledoc """
  Functions to generate embeddings using the OpenAI API.
  """

  @embeddings_url "https://api.openai.com/v1/embeddings"

  @doc """
  Passes the value of `rag_state` at `source_key` to the OpenAI API to generate an embedding.
  Then, puts the embedding in `rag_state` at `target_key`.
  """
  @type embedding :: list(number())
  @spec generate_embedding(
          map(),
          %{model: String.t(), api_key: String.t()},
          atom(),
          atom()
        ) :: %{
          atom() => embedding(),
          optional(any) => any
        }
  def generate_embedding(rag_state, openai_params, source_key, target_key) do
    text = Map.fetch!(rag_state, source_key)

    %{model: model, api_key: api_key} = openai_params

    metadata = %{embeddings_url: @embeddings_url, model: model, rag_state: rag_state}

    [result] =
      :telemetry.span([:rag, :generate_embedding], metadata, fn ->
        result =
          Req.post!(@embeddings_url,
            auth: {:bearer, api_key},
            json: %{model: model, input: text}
          ).body["data"]

        {result, metadata}
      end)

    embedding = result["embedding"]

    Map.put(rag_state, target_key, embedding)
  end

  @doc """
  Passes the values of each element of `rag_state_list` at `source_key` as a batch to the OpenAI API to generate all embeddings at once.
  Then, puts the embedding in each element of `rag_state_list` at `target_key`.
  """
  @spec generate_embeddings_batch(
          list(map()),
          %{model: String.t(), api_key: String.t()},
          atom(),
          atom()
        ) ::
          list(%{atom() => embedding(), optional(any) => any})
  def generate_embeddings_batch(
        rag_state_list,
        openai_params,
        source_key,
        target_key
      ) do
    texts = Enum.map(rag_state_list, &Map.fetch!(&1, source_key))

    %{model: model, api_key: api_key} = openai_params

    metadata = %{embeddings_url: @embeddings_url, model: model, rag_state_list: rag_state_list}

    results =
      :telemetry.span([:rag, :generate_embeddings_batch], metadata, fn ->
        result =
          Req.post!(@embeddings_url,
            auth: {:bearer, api_key},
            json: %{model: model, input: texts}
          ).body["data"]

        {result, metadata}
      end)

    embeddings = Enum.map(results, &Map.fetch!(&1, "embedding"))

    Enum.zip(rag_state_list, embeddings)
    |> Enum.map(fn {rag_state, embedding} ->
      Map.put(rag_state, target_key, embedding)
    end)
  end
end
