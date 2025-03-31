defmodule Rag.Evaluation.NxTest do
  use ExUnit.Case
  use Mimic

  alias Rag.Generation
  alias Rag.Evaluation
  alias Rag.Ai

  setup do
    %{provider: Ai.Nx.new(%{text_serving: TestTextServing})}
  end

  describe "evaluate_rag_triad/2" do
    test "takes a query, context, and response and returns an evaluation with scores and reasoning",
         %{provider: provider} do
      expect(Nx.Serving, :batched_run, fn _serving, _prompt ->
        %{
          results: [
            %{
              text: """
                \{
                \"answer_relevance_reasoning\"\: \"It is absolutely relevant\",
                \"answer_relevance_score\"\: 5,
                \"context_relevance_reasoning\"\: \"It's somewhat relevant\",
                \"context_relevance_score\"\: 3,
                \"groundedness_reasoning\"\: \"It's mostly grounded\",
                \"groundedness_score\"\: 4
                \}
              """
            }
          ]
        }
      end)

      generation = %Generation{
        query: "What's with this?",
        context: "This is a test",
        response: "It's a test"
      }

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
             } = Evaluation.evaluate_rag_triad(generation, provider)
    end

    @tag :skip
    test "fails with 'Streaming' if the response is streaming" do
    end
  end

  describe "detect_hallucination/2" do
    test "sets evaluation `:hallucination` to true if response does not equal \"YES\"", %{
      provider: provider
    } do
      expect(Nx.Serving, :batched_run, fn _serving, _prompt ->
        %{
          results: [
            %{text: "something something"}
          ]
        }
      end)

      generation =
        %Generation{
          query: "an important query",
          context: "some context",
          response: "this is something completely unrelated"
        }

      assert %Generation{evaluations: %{hallucination: true}} =
               Evaluation.detect_hallucination(
                 generation,
                 provider
               )
    end

    test "fails with 'Streaming' if the response is streaming" do
    end
  end
end
