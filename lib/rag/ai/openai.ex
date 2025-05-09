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
    req_params = build_req_params(provider, prompt, opts)

    with {:ok, %Req.Response{status: 200} = response} <- Req.post(provider.text_url, req_params) do
      {:ok, get_text_or_stream(response)}
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
    Stream.flat_map(response.body, &sse_events_to_stream(&1))
  end

  defp get_text_or_stream(response) do
    get_in(response.body, ["choices", Access.at(0), "message", "content"])
  end

  defp sse_events_to_stream(response_chunk) do
    events = String.split(response_chunk, "\n\n", trim: true)

    Enum.map(events, fn event ->
      case parse_sse_event(event) do
        {:ok, "message", "[DONE]"} -> ""
        {:ok, "message", data} -> get_event_text(data)
        {:error, _error} -> ""
      end
    end)
  end

  # copied from https://github.com/tidewave-ai/mcp_proxy_elixir/blob/main/lib/mcp_proxy/sse.ex
  # messages starting with : are considered to be comments
  # https://developer.mozilla.org/en-US/docs/Web/API/Server-sent_events/Using_server-sent_events#event_stream_format
  defp parse_sse_event(":" <> _), do: :ignore

  defp parse_sse_event(data) do
    lines = String.split(data, "\n", trim: true)

    event_type =
      lines
      |> Enum.find(fn line -> String.starts_with?(line, "event:") end)
      |> case do
        nil -> "message"
        line -> String.trim(String.replace_prefix(line, "event:", ""))
      end

    data_line =
      lines
      |> Enum.find(fn line -> String.starts_with?(line, "data:") end)
      |> case do
        nil -> nil
        line -> String.trim(String.replace_prefix(line, "data:", ""))
      end

    case data_line do
      nil -> {:error, "No data found in SSE event"}
      data -> {:ok, event_type, data}
    end
  end

  defp get_event_text(event) do
    case Jason.decode!(event) do
      %{"object" => "chat.completion.chunk"} = event ->
        get_in(event, ["choices", Access.at(0), "delta", "content"])

      _other_event_type ->
        ""
    end
  end
end
