defmodule Rag.Evaluation.HttpTest do
  use ExUnit.Case
  use Mimic

  alias Rag.Generation
  alias Rag.Evaluation
  alias Rag.Ai.Http.GenerationParams

  describe "evaluate_rag_triad/2" do
    test "takes a query, context, and response and returns an evaluation with scores and reasoning" do
      expect(Req, :post, fn _url, _params ->
        {:ok,
         %Req.Response{
           status: 200,
           body: %{
             "choices" => [
               %{
                 "message" => %{
                   "content" =>
                     %{
                       "answer_relevance_reasoning" => "It is absolutely relevant",
                       "answer_relevance_score" => 5,
                       "context_relevance_reasoning" => "It's somewhat relevant",
                       "context_relevance_score" => 3,
                       "groundedness_reasoning" => "It's mostly grounded",
                       "groundedness_score" => 4
                     }
                     |> Jason.encode!()
                 }
               }
             ]
           }
         }}
      end)

      generation = %Generation{
        query: "What's with this?",
        context: "This is a test",
        response: "It's a test"
      }

      openai_params = GenerationParams.openai_params("gpt-4o-mini", "my_key")

      assert %Generation{
               evaluations: %{
                 rag_triad: %{
                   "answer_relevance_reasoning" => "It is absolutely relevant",
                   "answer_relevance_score" => 5,
                   "context_relevance_reasoning" => "It's somewhat relevant",
                   "context_relevance_score" => 3,
                   "groundedness_reasoning" => "It's mostly grounded",
                   "groundedness_score" => 4
                 }
               }
             } =
               Evaluation.Http.evaluate_rag_triad(
                 generation,
                 openai_params
               )
    end
  end

  describe "detect_hallucination/2" do
    test "sets evaluation `:hallucination` to true if response does not equal \"YES\"" do
      expect(Req, :post, fn _url, _params ->
        {:ok,
         %Req.Response{
           status: 200,
           body: %{"choices" => [%{"index" => 0, "message" => %{"content" => "NO way"}}]}
         }}
      end)

      query = "an important query"
      context = "some context"
      response = "this is something completely unrelated"
      params = GenerationParams.openai_params("openai_model", "somekey")

      assert %Generation{evaluations: %{hallucination: true}} =
               Evaluation.Http.detect_hallucination(
                 %Generation{
                   query: query,
                   context: context,
                   response: response
                 },
                 params
               )
    end

    @tag :integration_test
    test "openai evaluation" do
      api_key = System.get_env("OPENAI_API_KEY")
      params = GenerationParams.openai_params("gpt-4o-mini", api_key)

      query = "When was Elixir 1.18.1 released?"
      context = "Elixir 1.18.1 was released on 2024-12-24"
      response = "It was released in October 2024"

      generation = %Generation{query: query, context: context, response: response}

      %Generation{evaluations: %{hallucination: true}} =
        Evaluation.Http.detect_hallucination(generation, params)
    end

    @tag :integration_test
    test "cohere evaluation" do
      api_key = System.get_env("COHERE_API_KEY")
      params = GenerationParams.cohere_params("command-r-plus-08-2024", api_key)

      query = "When was Elixir 1.18.1 released?"
      context = "Elixir 1.18.1 was released on 2024-12-24"
      response = "It was released in October 2024"

      generation = %Generation{query: query, context: context, response: response}

      %Generation{evaluations: %{hallucination: true}} =
        Evaluation.Http.detect_hallucination(generation, params)
    end
  end
end
