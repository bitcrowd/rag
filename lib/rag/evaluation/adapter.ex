defmodule Rag.Evaluation.Adapter do
  @moduledoc """
  Behaviour for evaluation.
  """

  @doc """
  Evaluates the response, query, and context according to the [RAG triad](https://www.trulens.org/getting_started/core_concepts/rag_triad/).
  - context relevance: is the retrieved context relevant to the query?
  - groundedness: is the response supported by the context?
  - answer relevance: is the answer relevant to the query?
  """
  @callback evaluate_rag_triad(generation :: Rag.Generation.t(), adapter_params :: any()) ::
              Rag.Generation.t()

  @doc """
  Takes the values of `query`, `response` and `context` from `generation` and passes it to the adapter using `adapter_params` to detect potential hallucinations.
  Then, puts a new `hallucination` evaluation in `generation.evaluations`.
  """
  @callback detect_hallucination(generation :: Rag.Generation.t(), adapter_params :: any()) ::
              Rag.Generation.t()
end
