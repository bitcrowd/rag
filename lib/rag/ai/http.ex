defmodule Rag.Ai.Http do
  @moduledoc """
  Implementation of `Rag.Ai` using HTTP.
  """

  @behaviour Rag.Ai

  alias Rag.Ai.Http.{EmbeddingParams, GenerationParams}

  @type embedding :: list(number())

  @impl Rag.Ai
  @spec generate_embedding(String.t(), EmbeddingParams.t()) :: embedding()
  def generate_embedding(text, params) do
    params = EmbeddingParams.set_input(params, text)

    response = Req.post!(params.url, params.req_params)

    [embedding] = get_embeddings(response, params)

    embedding
  end

  @impl Rag.Ai
  @spec generate_embeddings_batch(list(String.t()), EmbeddingParams.t()) :: list(embedding())
  def generate_embeddings_batch(texts, params) do
    params = EmbeddingParams.set_input(params, texts)

    Req.post!(params.url, params.req_params)
    |> get_embeddings(params)
  end

  defp get_embeddings(response, params), do: get_in(response.body, params.access_embeddings)

  @impl Rag.Ai
  @spec generate_response(String.t(), GenerationParams.t()) :: String.t()
  def generate_response(prompt, params) do
    params = GenerationParams.set_input(params, prompt)

    Req.post!(params.url, params.req_params)
    |> get_response(params)
  end

  defp get_response(response, params), do: get_in(response.body, params.access_response)
end
