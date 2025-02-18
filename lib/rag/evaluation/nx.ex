defmodule Rag.Evaluation.Nx do
  @moduledoc """
  Implementation of `Rag.Evaluation.Adapter` using `Nx`.
  """

  @behaviour Rag.Evaluation.Adapter

  alias Rag.{Evaluation, Generation}
  alias Rag.Ai

  @doc """
  Evaluates the response, query, and context according to the [RAG triad](https://www.trulens.org/getting_started/core_concepts/rag_triad/).
  - context relevance: is the retrieved context relevant to the query?
  - groundedness: is the response supported by the context?
  - answer relevance: is the answer relevant to the query?

  Prompts from https://github.com/truera/trulens/blob/main/src/feedback/trulens/feedback/prompts.py
  """
  @impl Rag.Evaluation.Adapter
  @spec evaluate_rag_triad(Generation.t(), Nx.Serving.t()) :: Generation.t()
  def evaluate_rag_triad(%Generation{} = generation, serving),
    do: Evaluation.evaluate_rag_triad(generation, serving, &Ai.Nx.generate_response/2)

  @doc """
  Takes the values of `query`, `response` and `context` from `generation` and passes it to `serving` to detect potential hallucinations.
  Then, puts a new `hallucination` evaluation in `generation.evaluations`.
  """
  @impl Rag.Evaluation.Adapter
  @spec detect_hallucination(Generation.t(), serving :: Nx.Serving.t()) :: Generation.t()
  def detect_hallucination(%Generation{} = generation, serving),
    do: Evaluation.detect_hallucination(generation, serving, &Ai.Nx.generate_response/2)
end
