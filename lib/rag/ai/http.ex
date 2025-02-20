defmodule Rag.Ai.Http do
  @moduledoc """
  Implementation of `Rag.Ai` using HTTP.
  """

  @behaviour Rag.Ai

  alias Rag.Ai.Http.{EmbeddingParams, GenerationParams}

  @type embedding :: list(number())

  @impl Rag.Ai
  @spec generate_embedding(String.t(), EmbeddingParams.t()) ::
          {:ok, embedding()} | {:error, any()}
  def generate_embedding(text, params) do
    params = EmbeddingParams.set_input(params, text)

    with {:ok, %Req.Response{status: 200} = response} <- Req.post(params.url, params.req_params),
         {:access, [embedding]} <- {:access, get_embeddings(response, params)} do
      {:ok, embedding}
    else
      {:ok, %Req.Response{status: status}} ->
        {:error, "HTTP request failed with status code #{status}"}

      {:error, reason} ->
        {:error, reason}

      {:access, reason} ->
        {:error, reason}
    end
  end

  @impl Rag.Ai
  @spec generate_embeddings_batch(list(String.t()), EmbeddingParams.t()) ::
          {:ok, list(embedding())} | {:error, any()}
  def generate_embeddings_batch(texts, params) do
    params = EmbeddingParams.set_input(params, texts)

    with {:ok, %Req.Response{status: 200} = response} <- Req.post(params.url, params.req_params),
         {:access, embeddings} <- {:access, get_embeddings(response, params)} do
      {:ok, embeddings}
    else
      {:ok, %Req.Response{status: status}} ->
        {:error, "HTTP request failed with status code #{status}"}

      {:error, reason} ->
        {:error, reason}

      {:access, reason} ->
        {:error, reason}
    end
  end

  defp get_embeddings(response, params), do: get_in(response.body, params.access_embeddings)

  @impl Rag.Ai
  @spec generate_response(String.t(), GenerationParams.t()) :: {:ok, String.t()} | {:error, any()}
  def generate_response(prompt, params) do
    params = GenerationParams.set_input(params, prompt)

    with {:ok, %Req.Response{status: 200} = response} <- Req.post(params.url, params.req_params),
         {:access, response} <- {:access, get_response(response, params)} do
      {:ok, response}
    else
      {:ok, %Req.Response{status: status}} ->
        {:error, "HTTP request failed with status code #{status}"}

      {:error, reason} ->
        {:error, reason}

      {:access, reason} ->
        {:error, reason}
    end
  end

  defp get_response(response, params), do: get_in(response.body, params.access_response)
end
