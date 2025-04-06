defmodule Rag.Ai.OpenAI do
  @moduledoc """
  Implementation of `Rag.Ai.Provider` using the OpenAI API.
  """

  @behaviour Rag.Ai.Provider

  @type t :: %__MODULE__{
          embeddings_url: String.t() | nil,
          embeddings_model: String.t() | nil,
          text_url: String.t() | nil,
          text_model: String.t() | nil,
          api_key: String.t() | nil
        }
  defstruct embeddings_url: "https://api.openai.com/v1/embeddings",
            embeddings_model: nil,
            text_url: "https://api.openai.com/v1/chat/completions",
            text_model: nil,
            api_key: nil

  @impl Rag.Ai.Provider
  def new(attrs) do
    struct!(__MODULE__, attrs)
  end

  @impl Rag.Ai.Provider
  def generate_embeddings(%__MODULE__{} = provider, texts, _opts \\ []) do
    req_params =
      [
        auth: {:bearer, provider.api_key},
        json: %{"model" => provider.embeddings_model, "input" => texts}
      ]

    with {:ok, %Req.Response{status: 200} = response} <-
           Req.post(provider.embeddings_url, req_params),
         {:ok, embeddings} <- get_embeddings(response) do
      {:ok, embeddings}
    else
      {:ok, %Req.Response{status: status}} ->
        {:error, "HTTP request failed with status code #{status}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_embeddings(response) do
    path = ["data", Access.all(), "embedding"]

    case get_in(response.body, path) do
      nil ->
        {:error,
         "failed to access embeddings from path data.[].embedding in response #{response.body}"}

      embeddings ->
        {:ok, embeddings}
    end
  end

  @impl Rag.Ai.Provider
  def generate_text(%__MODULE__{} = provider, prompt, _opts \\ []) do
    req_params =
      [
        auth: {:bearer, provider.api_key},
        json: %{"model" => provider.text_model, "messages" => [%{role: :user, content: prompt}]}
      ]

    with {:ok, %Req.Response{status: 200} = response} <- Req.post(provider.text_url, req_params),
         {:ok, text} <- get_text(response) do
      {:ok, text}
    else
      {:ok, %Req.Response{status: status}} ->
        {:error, "HTTP request failed with status code #{status}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_text(response) do
    path = ["choices", Access.at(0), "message", "content"]

    case get_in(response.body, path) do
      nil ->
        {:error,
         "failed to access text from path choices.0.message.content in response #{response.body}"}

      text ->
        {:ok, text}
    end
  end
end
