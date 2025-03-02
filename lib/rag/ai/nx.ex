defmodule Rag.Ai.Nx do
  @moduledoc """
  Implementation of `Rag.Ai.Provider` using `Nx`.
  """

  @behaviour Rag.Ai.Provider

  @type t :: %__MODULE__{
          embeddings_serving: Nx.Serving.t(),
          text_serving: Nx.Serving.t()
        }
  defstruct [:embeddings_serving, :text_serving]

  @impl Rag.Ai.Provider
  def new(attrs) do
    struct!(__MODULE__, attrs)
  end

  @impl Rag.Ai.Provider
  def generate_embeddings(%__MODULE__{} = provider, texts, _opts \\ []) when is_list(texts) do
    try do
      embeddings =
        Nx.Serving.batched_run(provider.embeddings_serving, texts)
        |> Enum.map(&Nx.to_list(&1.embedding))

      {:ok, embeddings}
    rescue
      error ->
        {:error, error}
    end
  end

  @impl Rag.Ai.Provider
  def generate_text(%__MODULE__{} = provider, prompt, _opts \\ []) when is_binary(prompt) do
    try do
      %{results: [result]} =
        Nx.Serving.batched_run(provider.text_serving, prompt)

      {:ok, result.text}
    rescue
      error ->
        {:error, error}
    end
  end
end
