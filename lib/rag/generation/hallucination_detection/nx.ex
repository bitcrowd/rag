defmodule Rag.Generation.HallucinationDetection.Nx do
  @moduledoc """
  Functions to detect hallucinations in generated responses using `Nx.Serving.batched_run/2`.
  """

  alias Rag.Generation

  @doc """
  Takes the values of `query`, `response` and `context` from `generation` and passes it to `serving` to detect potential hallucinations.
  Then, puts `hallucination?` in `generation`.
  """
  @spec detect_hallucination(Generation.t(), Nx.Serving.t()) :: Generation.t()
  def detect_hallucination(
        %Generation{} = generation,
        serving \\ Rag.HallucinationDetectionServing
      ) do
    %{query: query, response: response, context: context} = generation

    prompt =
      """
      <|system|>
      You are a helpful assistant.</s>
      <|user|>
      Context information is below.
      ---------------------
      #{context}
      ---------------------
      Given the context information and the query: does the response represent a correct answer only based on the context?
      Produce ONLY the following output: 'YES' or 'NO'
      Query: #{query}
      Response: #{response} </s>
      <|assistant|>
      """

    metadata = %{serving: serving, generation: generation}

    :telemetry.span([:rag, :detect_hallucination], metadata, fn ->
      %{results: [result]} = Nx.Serving.batched_run(serving, prompt)

      hallucination? = result.text != "YES"

      generation = put_in(generation, [Access.key!(:evaluations), :hallucination], hallucination?)

      {generation, %{metadata | generation: generation}}
    end)
  end
end
