defmodule Rag.Embedding.Params do
  @moduledoc """
  Parameter definitions for embeddings via HTTP API.
  """

  @params %{
    openai: [
      url: "https://api.openai.com/v1/embeddings",
      input_key: "input",
      json: %{}
    ],
    cohere: [
      url: "https://api.cohere.com/v2/embed",
      input_key: "texts",
      json: %{
        "input_type" => "search_document",
        "embedding_types" => ["float"]
      }
    ]
  }

  def openai_params(model, api_key) do
    @params.openai
    |> Keyword.put(:auth, {:bearer, api_key})
    |> put_in([:json, "model"], model)
    |> Keyword.put(:access_embedding_function, fn response_body ->
      results = response_body["data"]

      embeddings = Enum.map(results, & &1["embedding"])

      embeddings
    end)
  end

  def cohere_params(model, api_key) do
    @params.cohere
    |> Keyword.put(:auth, {:bearer, api_key})
    |> put_in([:json, "model"], model)
    |> Keyword.put(:access_embedding_function, fn response_body ->
      results = response_body["embeddings"]["float"]

      embeddings = results

      embeddings
    end)
  end
end
