defmodule Rag.Ai.Nx do
  @moduledoc """
  Implementation of `Rag.Ai` using `Nx`.
  """

  @behaviour Rag.Ai

  @type embedding :: list(number())

  @impl Rag.Ai
  @spec generate_embedding(String.t(), Nx.Serving.t()) :: {:ok, embedding()} | {:error, any()}
  def generate_embedding(text, serving) do
    try do
      %{embedding: embedding} = Nx.Serving.batched_run(serving, text)
      {:ok, Nx.to_list(embedding)}
    rescue
      error ->
        {:error, error}
    end
  end

  @impl Rag.Ai
  @spec generate_embeddings_batch(list(String.t()), Nx.Serving.t()) ::
          {:ok, list(embedding())} | {:error, any()}
  def generate_embeddings_batch(texts, serving) when is_list(texts) do
    try do
      embeddings =
        Nx.Serving.batched_run(serving, texts)
        |> Enum.map(&Nx.to_list(&1.embedding))

      {:ok, embeddings}
    rescue
      error ->
        {:error, error}
    end
  end

  @impl Rag.Ai
  @spec generate_response(String.t(), Nx.Serving.t()) :: {:ok, String.t()} | {:error, any()}
  def generate_response(prompt, serving) when is_binary(prompt) do
    try do
      %{results: [result]} =
        Nx.Serving.batched_run(serving, prompt)

      {:ok, result.text}
    rescue
      error ->
        {:error, error}
    end
  end
end
