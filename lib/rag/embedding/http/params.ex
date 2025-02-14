defmodule Rag.Embedding.Http.Params do
  @moduledoc """
  Parameter definitions for embeddings via HTTP API.
  """

  @type t :: %__MODULE__{
          url: String.t(),
          input_key: String.t(),
          access_embeddings: list(any()),
          req_params: keyword()
        }

  @enforce_keys [:url, :input_key, :access_embeddings, :req_params]
  defstruct [:url, :input_key, :access_embeddings, :req_params]

  @doc """
  Returns params to work with the OpenAI API.
  """
  @spec openai_params(String.t(), String.t(), keyword()) :: t()
  def openai_params(model, api_key, req_params \\ []) do
    %__MODULE__{
      url: "https://api.openai.com/v1/embeddings",
      input_key: "input",
      access_embeddings: ["data", Access.all(), "embedding"],
      req_params:
        Keyword.merge(
          [
            auth: {:bearer, api_key},
            json: %{"model" => model}
          ],
          req_params
        )
    }
  end

  @doc """
  Returns params to work with the Cohere API.
  """
  @spec cohere_params(String.t(), String.t(), keyword()) :: t()
  def cohere_params(model, api_key, req_params \\ []) do
    %__MODULE__{
      url: "https://api.cohere.com/v2/embed",
      input_key: "texts",
      access_embeddings: ["embeddings", "float"],
      req_params:
        Keyword.merge(
          [
            auth: {:bearer, api_key},
            json: %{
              "model" => model,
              "input_type" => "search_document",
              "embedding_types" => ["float"]
            }
          ],
          req_params
        )
    }
  end

  @doc """
  Adds `value` at `key_or_keys` in `params.req_params`.
  """
  @spec put_req_param(t(), any(), any()) :: t()
  def put_req_param(params, key_or_keys, value) do
    keys = List.wrap(key_or_keys)

    put_in(params, [Access.key!(:req_params) | keys], value)
  end

  @doc """
  Sets `input` at the correct place in `params` to work as input value for the API call.
  """
  @spec set_input(t(), any()) :: t()
  def set_input(params, input),
    do: put_req_param(params, [:json, params.input_key], List.wrap(input))
end
