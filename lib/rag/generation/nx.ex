defmodule Rag.Generation.Nx do
  @moduledoc """
  Functions to generate responses using `Nx.Serving.batched_run/2`. 
  """

  @doc """
  Passes `prompt` from `rag_state` to `serving` to generate a response.
  Then, puts `response` in `rag_state`.
  """
  @spec generate_response(%{prompt: String.t()}, Nx.Serving.t()) :: %{response: String.t()}
  def generate_response(rag_state, serving \\ Rag.LLMServing) do
    %{prompt: prompt} = rag_state

    metadata = %{serving: serving, rag_state: rag_state}

    %{results: [result]} =
      :telemetry.span([:rag, :generate_response], metadata, fn ->
        result = Nx.Serving.batched_run(serving, prompt)

        {result, metadata}
      end)

    Map.put(rag_state, :response, result.text)
  end
end
