defmodule Rag.Evaluation.Nx do
  @moduledoc """
  Implementation of `Rag.Evaluation.Adapter` using `Nx`.
  """

  @behaviour Rag.Evaluation.Adapter

  alias Rag.Generation

  @doc """
  Evaluates the response, query, and context according to the [RAG triad](https://www.trulens.org/getting_started/core_concepts/rag_triad/).
  - context relevance: is the retrieved context relevant to the query?
  - groundedness: is the response supported by the context?
  - answer relevance: is the answer relevant to the query?

  Prompts from https://github.com/truera/trulens/blob/main/src/feedback/trulens/feedback/prompts.py
  """
  @impl Rag.Evaluation.Adapter
  @spec evaluate_rag_triad(Generation.t(), Nx.Serving.t()) :: Generation.t()
  def evaluate_rag_triad(%Generation{halted?: true} = generation, _serving), do: generation

  @impl Rag.Evaluation.Adapter
  def evaluate_rag_triad(%Generation{} = generation, serving) do
    %{response: response, query: query, context: context} = generation

    system_prompt =
      "You are a special evaluator assistant who is very proficient in giving ratings between 1 and 5 according to a task description."

    user_prompt = """
    Task Description:
    A query, a context, a response to evaluate, and a score rubric representing a evaluation criteria are given.
    1. Assess the quality of the response strictly based on the given score rubric, not evaluating in general.
    2. For each criteria given in the score rubric, reason what the score would be, then write a score that is an integer between 1 and 5. You should refer to the score rubric.

    The query:
    #{query}

    The context:
    #{context}

    Response to evaluate:
    #{response}

    Score Rubrics:
    [Is the context relevant to the query?]
    Score 1: The context is completely irrelevant.
    Score 2: The context is mostly irrelevant.
    Score 3: The context is somewhat relevant.
    Score 4: The context is mostly relevant.
    Score 5: The context is completely relevant.

    [Is the response supported by the context?]
    Score 1: The response is completely supported by the context.
    Score 2: The response is mostly supported by the context.
    Score 3: The response is somewhat supported by the context.
    Score 4: The response is mostly supported by the context.
    Score 5: The response is completely supported by the context.

    [Is the answer relevant to the query?]
    Score 1: The response is completely relevant to the query.
    Score 2: The response is mostly relevant to the query.
    Score 3: The response is somewhat relevant to the query.
    Score 4: The response is mostly relevant to the query.
    Score 5: The response is completely relevant to the query.
    """

    prompt = """
    #{system_prompt}

    #{user_prompt}
    """

    metadata = %{generation: generation, serving: serving}

    :telemetry.span([:rag, :evaluate_rag_triad], metadata, fn ->
      %{results: [result]} = Nx.Serving.batched_run(serving, prompt)

      evaluation = Jason.decode!(result.text)

      generation = Generation.put_evaluation(generation, :rag_triad, evaluation)

      {generation, %{metadata | generation: generation}}
    end)
  end

  @doc """
  Takes the values of `query`, `response` and `context` from `generation` and passes it to `serving` to detect potential hallucinations.
  Then, puts a new `hallucination` evaluation in `generation.evaluations`.
  """
  @impl Rag.Evaluation.Adapter
  @spec detect_hallucination(Generation.t(), serving :: Nx.Serving.t()) :: Generation.t()
  def detect_hallucination(%Generation{halted?: true} = generation, _serving), do: generation

  @impl Rag.Evaluation.Adapter
  def detect_hallucination(%Generation{} = generation, serving) do
    %{query: query, response: response, context: context} = generation

    prompt =
      """
      Context information is below.
      ---------------------
      #{context}
      ---------------------
      Given the context information and the query: does the response represent a correct answer only based on the context?
      Produce ONLY the following output: YES or NO
      If the response represents a correct answer only based on the context, output: YES
      If the response does not represent a correct answer only based on the context, output: NO
      Query: #{query}
      Response: #{response}
      output:
      """

    metadata = %{generation: generation, serving: serving}

    :telemetry.span([:rag, :detect_hallucination], metadata, fn ->
      %{results: [result]} = Nx.Serving.batched_run(serving, prompt)

      hallucination? = result.text != "YES"

      generation = Generation.put_evaluation(generation, :hallucination, hallucination?)

      {generation, %{metadata | generation: generation}}
    end)
  end
end
