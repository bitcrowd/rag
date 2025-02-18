defmodule Rag.Evaluation.Http do
  @moduledoc """
  Implementation of `Rag.Evaluation.Adapter` using HTTP.
  """

  @behaviour Rag.Evaluation.Adapter

  alias Rag.{Evaluation, Generation}
  alias Rag.Ai
  alias Rag.Ai.Http.GenerationParams

  @doc """
  Evaluates the response, query, and context according to the [RAG triad](https://www.trulens.org/getting_started/core_concepts/rag_triad/).
  - context relevance: is the retrieved context relevant to the query?
  - groundedness: is the response supported by the context?
  - answer relevance: is the answer relevant to the query?

  Prompts from https://github.com/truera/trulens/blob/main/src/feedback/trulens/feedback/prompts.py
  """
  @impl Rag.Evaluation.Adapter
  @spec evaluate_rag_triad(Generation.t(), GenerationParams.t()) :: Generation.t()
  def evaluate_rag_triad(%Generation{} = generation, params) do
    response_format =
      %{
        type: :json_schema,
        json_schema: %{
          name: :evaluation_schema,
          strict: true,
          schema: %{
            type: :object,
            properties: %{
              context_relevance_reasoning: %{type: :string},
              context_relevance_score: %{type: :integer},
              groundedness_reasoning: %{type: :string},
              groundedness_score: %{type: :integer},
              answer_relevance_reasoning: %{type: :string},
              answer_relevance_score: %{type: :integer}
            },
            additionalProperties: false,
            required: [
              :context_relevance_reasoning,
              :context_relevance_score,
              :groundedness_reasoning,
              :groundedness_score,
              :answer_relevance_reasoning,
              :answer_relevance_score
            ]
          }
        }
      }

    params =
      params
      |> GenerationParams.put_req_param([:json, :response_format], response_format)
      |> GenerationParams.set_input(generation.prompt)

    Evaluation.evaluate_rag_triad(generation, params, &Ai.Http.generate_response/2)
  end

  @doc """
  Takes the values of `query`, `response` and `context` from `generation` and passes it to the adapter specified by `params` to detect potential hallucinations.
  Then, puts a new `hallucination` evaluation in `generation.evaluations`.
  """
  @impl Rag.Evaluation.Adapter
  @spec detect_hallucination(Generation.t(), GenerationParams.t()) :: Generation.t()
  def detect_hallucination(%Generation{} = generation, params) do
    params = GenerationParams.set_input(params, generation.prompt)

    Evaluation.detect_hallucination(generation, params, &Ai.Http.generate_response/2)
  end
end
