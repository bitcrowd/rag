defmodule Rag.Ai.Nx do
  @moduledoc """
  Implementation of `Rag.Ai.Provider` using `Nx`.
  """

  @behaviour Rag.Ai.Provider

  @type t :: %__MODULE__{
          embeddings_serving: Nx.Serving.t() | nil,
          text_serving: Nx.Serving.t() | nil
        }
  defstruct [:embeddings_serving, :text_serving]

  @impl Rag.Ai.Provider
  def new(attrs) do
    struct!(__MODULE__, attrs)
  end

  @impl Rag.Ai.Provider
  def generate_embeddings(provider, texts, opts \\ [])

  def generate_embeddings(%__MODULE__{embeddings_serving: nil}, _texts, _opts) do
    raise ArgumentError,
          "provider.embeddings_serving is nil but must point to valid embeddings serving, for instance created with Bumblebee.Text.TextEmbedding.text_embedding/3"
  end

  def generate_embeddings(%__MODULE__{} = provider, texts, _opts) when is_list(texts) do
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
  def generate_text(provider, prompt, opts \\ [])

  def generate_text(%__MODULE__{text_serving: nil}, _prompt, _opts) do
    raise ArgumentError,
          "provider.text_serving is nil but must point to valid text serving, for instance created with Bumblebee.Text.generation/4"
  end

  def generate_text(%__MODULE__{} = provider, prompt, opts) when is_binary(prompt) do
    if opts[:stream] do
      raise ArgumentError,
            "The stream option has no effect when using Nx. Streaming must be configured when creating the serving"
    end

    case Nx.Serving.batched_run(provider.text_serving, prompt) do
      %{results: [result]} -> {:ok, result.text}
      stream -> {:ok, stream}
    end
  rescue
    error in ArgumentError ->
      reraise error, __STACKTRACE__

    error ->
      {:error, error}
  end
end
