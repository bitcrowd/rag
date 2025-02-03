defmodule Rag.Generation.Http do
  @moduledoc """
  Functions to generate responses using an HTTP API.
  """

  alias Rag.Generation
  alias Rag.Generation.Http.Params

  @doc """
  Passes `generation.prompt` to the HTTP API specified by `params` to generate a response.
  Then, puts `response` in `generation`.
  """
  @spec generate_response(Generation.t(), params :: Params.t()) :: Generation.t()
  def generate_response(%Generation{halted?: true} = generation, _params), do: generation

  def generate_response(%Generation{prompt: nil}, _serving),
    do: raise(ArgumentError, message: "prompt must not be nil")

  def generate_response(%Generation{} = generation, params) do
    params = Params.set_input(params, generation.prompt)

    metadata = %{generation: generation, params: params}

    :telemetry.span([:rag, :generate_response], metadata, fn ->
      response = Req.post!(params.url, params.req_params) |> get_response(params)

      generation = Generation.put_response(generation, response)

      {generation, %{metadata | generation: generation}}
    end)
  end

  defp get_response(response, params), do: get_in(response.body, params.access_response)
end
