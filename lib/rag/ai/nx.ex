defmodule Rag.Ai.Nx do
  @moduledoc """
  Implementation of `Rag.Ai` using `Nx`.
  """

  @behaviour Rag.Ai

  @type embedding :: list(number())

  @impl Rag.Ai
  @spec generate_embedding(String.t(), Nx.Serving.t()) :: embedding()
  def generate_embedding(text, serving) do
    %{embedding: embedding} = Nx.Serving.batched_run(serving, text)

    Nx.to_list(embedding)
  end

  @impl Rag.Ai
  @spec generate_embeddings_batch(list(String.t()), Nx.Serving.t()) :: list(embedding())
  def generate_embeddings_batch(texts, serving) when is_list(texts) do
    Nx.Serving.batched_run(serving, texts)
    |> Enum.map(&Nx.to_list(&1.embedding))
  end

  @impl Rag.Ai
  @spec generate_response(String.t(), Nx.Serving.t()) :: String.t()
  def generate_response(prompt, serving) when is_binary(prompt) do
    %{results: [result]} = Nx.Serving.batched_run(serving, prompt)

    result.text
  end
end
