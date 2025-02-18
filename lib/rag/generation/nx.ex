defmodule Rag.Generation.Nx do
  @moduledoc """
  Implementation of `Rag.Generation.Adapter` using `Nx`.
  """

  @behaviour Rag.Generation.Adapter

  alias Rag.Generation
  alias Rag.Ai

  @doc """
  Passes `generation.prompt` to `serving` to generate a response.
  Then, puts `response` in `generation`.
  """
  @impl Rag.Generation.Adapter
  @spec generate_response(Generation.t(), Nx.Serving.t()) :: Generation.t()
  def generate_response(%Generation{} = generation, serving),
    do: Generation.generate_response(generation, serving, &Ai.Nx.generate_response/2)
end
