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
         {:access, embeddings} <- {:access, get_embeddings(response)} do
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

  defp get_embeddings(response) do
    get_in(response.body, ["data", Access.all(), "embedding"])
  end

  @impl Rag.Ai.Provider
  def generate_text(%__MODULE__{} = provider, prompt, opts \\ []) do
    stream? = Keyword.get(opts, :stream, false)

    req_params =
      [
        auth: {:bearer, provider.api_key},
        json: %{
          "model" => provider.text_model,
          "messages" => [%{role: :user, content: prompt}],
          "stream" => stream?
        }
      ]

    with {:ok, %Req.Response{status: 200} = response} <- Req.post(provider.text_url, req_params),
         {:access, response} <- {:access, get_text(response)} do
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

  defp get_text(response) do
    get_in(response.body, ["choices", Access.at(0), "message", "content"])
  end
end
