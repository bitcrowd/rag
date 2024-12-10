defmodule Rag.Generation.HallucinationDetection.Nx do
  @moduledoc """
  Functions to detect hallucinations in generated responses using `Nx.Serving.batched_run/2`.
  """

  @doc """
  Takes the values of `query`, `response` and `context` from `rag_state` and passes it to `serving` to detect potential hallucinations.
  Then, puts `hallucination?` in `rag_state`.
  """
  @spec detect_hallucination(%{response: String.t()}, Nx.Serving.t()) :: %{hallucination?: bool()}
  def detect_hallucination(rag_state, serving \\ Rag.HallucinationDetectionServing) do
    %{query: query, response: response, context: context} = rag_state

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

    metadata = %{serving: serving, rag_state: rag_state}

    %{results: [result]} =
      :telemetry.span([:rag, :detect_hallucination], metadata, fn ->
        result = Nx.Serving.batched_run(serving, prompt)

        {result, metadata}
      end)

    hallucination? = result.text != "YES"

    Map.put(rag_state, :hallucination?, hallucination?)
  end
end
