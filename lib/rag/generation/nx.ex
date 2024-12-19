defmodule Rag.Generation.Nx do
  @moduledoc """
  Functions to generate responses using `Nx.Serving.batched_run/2`. 
  """

  alias Rag.Generation

  @doc """
  Passes `prompt` from `generation` to `serving` to generate a response.
  Then, puts `response` in `generation`.
  """
  @spec generate_response(Generation.t(), Nx.Serving.t()) :: Generation.t()
  def generate_response(generation, serving \\ Rag.LLMServing)

  def generate_response(%Generation{prompt: nil}, _serving),
    do: raise(ArgumentError, message: "prompt must not be nil")

  def generate_response(%Generation{prompt: prompt} = generation, serving)
      when is_binary(prompt) do
    metadata = %{serving: serving, generation: generation}

    :telemetry.span([:rag, :generate_response], metadata, fn ->
      %{results: [result]} = Nx.Serving.batched_run(serving, prompt)

      generation = %{generation | response: result.text}

      {generation, %{metadata | generation: generation}}
    end)
  end
end
