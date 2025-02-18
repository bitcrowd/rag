defmodule Rag.Generation.Http do
  @moduledoc """
  Implementation of `Rag.Generation.Adapter` using HTTP.
  """

  @behaviour Rag.Generation.Adapter

  alias Rag.Generation
  alias Rag.Ai
  alias Rag.Ai.Http.GenerationParams

  @doc """
  Passes `generation.prompt` to the HTTP API specified by `params` to generate a response.
  Then, puts `response` in `generation`.
  """
  @impl Rag.Generation.Adapter
  @spec generate_response(Generation.t(), GenerationParams.t()) :: Generation.t()
  def generate_response(%Generation{} = generation, params),
    do: Generation.generate_response(generation, params, &Ai.Http.generate_response/2)
end
