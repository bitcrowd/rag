defmodule Rag.Generation.Http do
  @moduledoc """
  Functions to generate responses using an HTTP API.
  """

  alias Rag.Generation

  @doc """
  Passes `generation.prompt` to the HTTP API specified by `params` to generate a response.
  Then, puts `response` in `generation`.

  ## Params

  Required:
   * `url`: URL of endpoint that is called
   * `put_prompt_function`: this function receives the params and prompt and must return new params with the prompt at the correct place for the request
   * `access_response_function`: this function receives the response body and must return the generated response

  The required params will be popped from `params`.
  All remaining params will be passed to `req`.
  """
  @spec generate_response(Generation.t(), params :: keyword()) :: Generation.t()
  def generate_response(%Generation{prompt: nil}, _serving),
    do: raise(ArgumentError, message: "prompt must not be nil")

  def generate_response(%Generation{} = generation, params) do
    {url, params} = Keyword.pop!(params, :url)
    {put_prompt_function, params} = Keyword.pop!(params, :put_prompt_function)
    {access_response_function, params} = Keyword.pop!(params, :access_response_function)

    params = put_prompt_function.(params, generation.prompt)
    metadata = %{generation: generation, url: url, params: params}

    :telemetry.span([:rag, :generate_response], metadata, fn ->
      response = Req.post!(url, params)

      response = access_response_function.(response.body)

      generation = Generation.put_response(generation, response)

      {generation, %{metadata | generation: generation}}
    end)
  end
end
