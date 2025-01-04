defmodule Rag.Generation.Http.Params do
  @moduledoc """
  Parameter definitions for generation via HTTP API.
  """

  @params %{
    openai: [
      url: "https://api.openai.com/v1/chat/completions",
      json: %{}
    ],
    cohere: [
      url: "https://api.cohere.com/v2/chat",
      json: %{}
    ]
  }

  def openai_params(model, api_key) do
    @params.openai
    |> Keyword.put(:auth, {:bearer, api_key})
    |> put_in([:json, "model"], model)
    |> Keyword.put(:put_prompt_function, fn params, prompt ->
      put_in(params, [:json, "messages"], [%{role: :user, content: prompt}])
    end)
    |> Keyword.put(:access_response_function, fn response_body ->
      results = Map.fetch!(response_body, "choices")

      response = Enum.max_by(results, &Map.fetch!(&1, "index"))

      Map.fetch!(response["message"], "content")
    end)
  end

  def cohere_params(model, api_key) do
    @params.cohere
    |> Keyword.put(:auth, {:bearer, api_key})
    |> put_in([:json, "model"], model)
    |> Keyword.put(:put_prompt_function, fn params, prompt ->
      put_in(params, [:json, "messages"], [%{role: :user, content: prompt}])
    end)
    |> Keyword.put(:access_response_function, fn response_body ->
      %{"message" => %{"content" => [%{"text" => response}]}} = response_body

      response
    end)
  end
end
