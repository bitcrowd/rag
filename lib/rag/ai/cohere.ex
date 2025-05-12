defmodule Rag.Ai.Cohere do
  @moduledoc """
  Implementation of `Rag.Ai.Provider` using the Cohere API.
  """

  @behaviour Rag.Ai.Provider

  @type t :: %__MODULE__{
          embeddings_url: String.t() | nil,
          embeddings_model: String.t() | nil,
          text_url: String.t() | nil,
          text_model: String.t() | nil,
          api_key: String.t() | nil
        }
  defstruct embeddings_url: "https://api.cohere.com/v2/embed",
            embeddings_model: nil,
            text_url: "https://api.cohere.com/v2/chat",
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
        json: %{
          "model" => provider.embeddings_model,
          "texts" => texts,
          "input_type" => "search_document",
          "embedding_types" => ["float"]
        }
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
    path = ["embeddings", "float"]

    case get_in(response.body, path) do
      nil ->
        {:error,
         "failed to access embedings from path embeddings.float in response #{response.body}"}

      embeddings ->
        {:ok, embeddings}
    end
  end

  @impl Rag.Ai.Provider
  def generate_text(%__MODULE__{} = provider, prompt, opts \\ []) do
    req_params = build_req_params(provider, prompt, opts)

    with {:ok, %Req.Response{status: 200} = response} <- Req.post(provider.text_url, req_params),
         {:ok, text_or_stream} <- get_text_or_stream(response) do
      {:ok, text_or_stream}
    else
      {:ok, %Req.Response{status: status}} ->
        {:error, "HTTP request failed with status code #{status}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_req_params(provider, prompt, opts) do
    stream? = Keyword.get(opts, :stream, false)

    base_params =
      [
        auth: {:bearer, provider.api_key},
        json: %{
          "model" => provider.text_model,
          "messages" => [%{role: :user, content: prompt}],
          "stream" => stream?
        }
      ]

    if stream? do
      Keyword.put(base_params, :into, :self)
    else
      base_params
    end
  end

  defp get_text_or_stream(%{body: %Req.Response.Async{}} = response) do
    {:ok, Stream.flat_map(response.body, &sse_events_to_stream(&1))}
  end

  defp get_text_or_stream(response), do: get_text(response)

  defp get_text(response) do
    path = ["message", "content", Access.at(0), "text"]

    case get_in(response.body, path) do
      nil ->
        {:error,
         "failed to access text from path message.content.0.text in response #{response.body}"}

      text ->
        {:ok, text}
    end
  end

  defp sse_events_to_stream(response_chunk) do
    events = String.split(response_chunk, "}\n", trim: true) |> Enum.map(&(&1 <> "}"))

    Enum.map(events, &get_event_text(&1))
  end

  defp get_event_text(event) do
    case Jason.decode!(event) do
      %{"type" => "content-delta"} = event ->
        get_in(event, ["delta", "message", "content", "text"])

      _other_event_type ->
        ""
    end
  end
end
