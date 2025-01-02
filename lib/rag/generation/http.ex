defmodule Rag.Generation.Http do
  @moduledoc """
  Functions to generate responses using an HTTP API.
  """

  alias Rag.Generation

  @doc """
  Passes `prompt` from `generation` to the HTTP API specified by `params` to generate a response.
  Then, puts `response` in `generation`.
  """
  @spec generate_response(Generation.t(), params :: keyword()) :: Generation.t()
  def generate_response(%Generation{} = generation, params) do
    {url, params} = Keyword.pop!(params, :url)
    {put_prompt_function, params} = Keyword.pop!(params, :put_prompt_function)
    {access_response_function, params} = Keyword.pop!(params, :access_response_function)

    params = put_prompt_function.(params, generation.prompt)
    metadata = %{generation: generation, url: url, params: params}

    :telemetry.span([:rag, :generate_response], metadata, fn ->
      response = Req.post!(url, params)

      response = access_response_function.(response.body)

      generation = put_in(generation, [Access.key!(:response)], response)

      {generation, %{metadata | generation: generation}}
    end)
  end
end
