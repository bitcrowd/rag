defmodule Rag.Evaluation.NxTest do
  use ExUnit.Case
  use Mimic

  alias Rag.Generation
  alias Rag.Evaluation

  describe "evaluate_rag_triad/2" do
    test "takes a query, context, and response and returns an evaluation with scores and reasoning" do
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

      serving = TestServing

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
             } = Evaluation.Nx.evaluate_rag_triad(generation, serving)
    end

    test "emits start, stop, and exception telemetry events" do
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

      serving = TestServing

      ref =
        :telemetry_test.attach_event_handlers(self(), [
          [:rag, :evaluate_rag_triad, :start],
          [:rag, :evaluate_rag_triad, :stop],
          [:rag, :evaluate_rag_triad, :exception]
        ])

      Evaluation.Nx.evaluate_rag_triad(generation, serving)

      assert_received {[:rag, :evaluate_rag_triad, :start], ^ref, _measurement, _meta}
      assert_received {[:rag, :evaluate_rag_triad, :stop], ^ref, _measurement, _meta}

      expect(Nx.Serving, :batched_run, fn _serving, _prompt -> raise "boom" end)

      assert_raise RuntimeError, fn ->
        Evaluation.Nx.evaluate_rag_triad(generation, serving)
      end

      assert_received {[:rag, :evaluate_rag_triad, :exception], ^ref, _measurement, _meta}
    end
  end

  describe "detect_hallucination/2" do
    test "sets evaluation `:hallucination` to true if response does not equal \"YES\"" do
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

      serving = TestServing

      assert %Generation{evaluations: %{hallucination: true}} =
               Evaluation.Nx.detect_hallucination(
                 generation,
                 serving
               )
    end

    test "sets evaluation `:hallucination` to false if response equals \"YES\"" do
      expect(Nx.Serving, :batched_run, fn _serving, _prompt ->
        %{
          results: [
            %{text: "YES"}
          ]
        }
      end)

      generation = %Generation{
        query: "an important query",
        context: "some context",
        response: "this is something related"
      }

      serving = TestServing

      assert %Generation{evaluations: %{hallucination: false}} =
               Evaluation.Nx.detect_hallucination(generation, serving)
    end

    test "emits start, stop, and exception telemetry events" do
      expect(Nx.Serving, :batched_run, fn _serving, _prompt ->
        %{
          results: [
            %{text: "not relevant"}
          ]
        }
      end)

      generation =
        %Generation{
          query: "an important query",
          context: "some context",
          response: "not relevant"
        }

      serving = TestServing

      ref =
        :telemetry_test.attach_event_handlers(self(), [
          [:rag, :detect_hallucination, :start],
          [:rag, :detect_hallucination, :stop],
          [:rag, :detect_hallucination, :exception]
        ])

      Evaluation.Nx.detect_hallucination(generation, serving)

      assert_received {[:rag, :detect_hallucination, :start], ^ref, _measurement, _meta}
      assert_received {[:rag, :detect_hallucination, :stop], ^ref, _measurement, _meta}

      expect(Nx.Serving, :batched_run, fn _serving, _prompt -> raise "boom" end)

      assert_raise RuntimeError, fn ->
        Evaluation.Nx.detect_hallucination(generation, serving)
      end

      assert_received {[:rag, :detect_hallucination, :exception], ^ref, _measurement, _meta}
    end
  end
end
