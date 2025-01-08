defmodule Rag.Evaluation.Http.Params do
  @moduledoc """
  Parameter definitions for evaluation via HTTP API.
  """

  @type t :: %__MODULE__{
          url: String.t(),
          message_key: String.t(),
          access_response: list(any()),
          req_params: keyword()
        }

  @enforce_keys [:url, :message_key, :access_response, :req_params]
  defstruct [:url, :message_key, :access_response, :req_params]

  def openai_params(model, api_key) do
    %__MODULE__{
      url: "https://api.openai.com/v1/chat/completions",
      message_key: "messages",
      access_response: ["choices", Access.at(0), "message", "content"],
      req_params: [
        auth: {:bearer, api_key},
        json: %{"model" => model}
      ]
    }
  end

  def cohere_params(model, api_key) do
    %__MODULE__{
      url: "https://api.cohere.com/v2/chat",
      message_key: "messages",
      access_response: ["message", "content", Access.at(0), "text"],
      req_params: [
        auth: {:bearer, api_key},
        json: %{"model" => model}
      ]
    }
  end

  def put_req_param(params, key_or_keys, value) do
    keys = List.wrap(key_or_keys)

    put_in(params, [Access.key!(:req_params) | keys], value)
  end

  def set_input(params, input) when is_binary(input),
    do: put_req_param(params, [:json, params.message_key], [%{role: :user, content: input}])

  def set_input(params, input) when is_list(input),
    do: put_req_param(params, [:json, params.message_key], input)
end
