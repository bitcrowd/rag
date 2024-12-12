defmodule Rag.Evaluation.OpenAI do
  @moduledoc """
  Evaluation for RAG systems using the OpenAI API.
  """

  @structured_outputs_url "https://api.openai.com/v1/chat/completions"

  @doc """
  Evaluates the response, query, and context according to the [RAG triad](https://www.trulens.org/getting_started/core_concepts/rag_triad/).
  - context relevance: is the retrieved context relevant to the query?
  - groundedness: is the response supported by the context?
  - answer relevance: is the answer relevant to the query?

  Prompts from https://github.com/truera/trulens/blob/main/src/feedback/trulens/feedback/prompts.py
  """
  def evaluate_rag_triad(rag_state, openai_params) do
    %{response: response, query: query, context: context} = rag_state

    %{model: model, api_key: api_key} = openai_params

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

    metadata = %{
      structed_outputs_url: @structured_outputs_url,
      model: model,
      rag_state: rag_state
    }

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

    evaluation =
      :telemetry.span([:rag, :evaluate_rag_triad], metadata, fn ->
        response =
          Req.post!(@structured_outputs_url,
            auth: {:bearer, api_key},
            json: %{
              model: model,
              messages: [
                %{role: :system, content: system_prompt},
                %{role: :user, content: user_prompt}
              ],
              response_format: response_format
            }
          )

        [result] = response.body["choices"]

        result = get_in(result, ["message", "content"])

        evaluation = Jason.decode!(result)

        {evaluation, metadata}
      end)

    Map.put(rag_state, :evaluation, evaluation)
  end
end
