defmodule Rag.EvaluationTest do
  use ExUnit.Case

  alias Rag.Generation
  alias Rag.Evaluation

  describe "evaluate_rag_triad/3" do
    test "takes a query, context, and response and returns an evaluation with scores and reasoning" do
      generation = %Generation{
        query: "What's with this?",
        context: "This is a test",
        response: "It's a test"
      }

      response_fn = fn _prompt, _params ->
        %{
          "answer_relevance_reasoning" => "It is absolutely relevant",
          "answer_relevance_score" => 5,
          "context_relevance_reasoning" => "It's somewhat relevant",
          "context_relevance_score" => 3,
          "groundedness_reasoning" => "It's mostly grounded",
          "groundedness_score" => 4
        }
        |> Jason.encode!()
      end

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
             } = Evaluation.evaluate_rag_triad(generation, %{}, response_fn)
    end

    test "returns unchanged generation when halted? is true" do
      generation = %Generation{
        query: "What's with this?",
        context: "This is a test",
        response: "It's a test",
        halted?: true
      }

      response_fn = fn _prompt, _params -> raise "unreachable" end

      assert generation == Evaluation.evaluate_rag_triad(generation, %{}, response_fn)
    end

    test "emits start, stop, and exception telemetry events" do
      generation = %Generation{
        query: "What's with this?",
        context: "This is a test",
        response: "It's a test"
      }

      response_fn = fn _prompt, _params ->
        %{
          "answer_relevance_reasoning" => "It is absolutely relevant",
          "answer_relevance_score" => 5,
          "context_relevance_reasoning" => "It's somewhat relevant",
          "context_relevance_score" => 3,
          "groundedness_reasoning" => "It's mostly grounded",
          "groundedness_score" => 4
        }
        |> Jason.encode!()
      end

      ref =
        :telemetry_test.attach_event_handlers(self(), [
          [:rag, :evaluate_rag_triad, :start],
          [:rag, :evaluate_rag_triad, :stop],
          [:rag, :evaluate_rag_triad, :exception]
        ])

      Evaluation.evaluate_rag_triad(generation, %{}, response_fn)

      assert_received {[:rag, :evaluate_rag_triad, :start], ^ref, _measurement, _meta}
      assert_received {[:rag, :evaluate_rag_triad, :stop], ^ref, _measurement, _meta}

      crashing_response_fn = fn _prompt, _params -> raise "boom" end

      assert_raise RuntimeError, fn ->
        Evaluation.evaluate_rag_triad(generation, %{}, crashing_response_fn)
      end

      assert_received {[:rag, :evaluate_rag_triad, :exception], ^ref, _measurement, _meta}
    end
  end

  describe "detect_hallucination/3" do
    test "sets evaluation `:hallucination` to true if response does not equal \"YES\"" do
      query = "an important query"
      context = "some context"
      response = "this is something completely unrelated"

      response_fn = fn _prompt, _params -> "NO way" end

      assert %Generation{evaluations: %{hallucination: true}} =
               Evaluation.detect_hallucination(
                 %Generation{
                   query: query,
                   context: context,
                   response: response
                 },
                 %{},
                 response_fn
               )
    end

    test "sets evaluation `:hallucination` to false if response equals \"YES\"" do
      query = "an important query"
      context = "some context"
      response = "this is something completely unrelated"

      response_fn = fn _prompt, _params -> "YES" end

      assert %Generation{evaluations: %{hallucination: false}} =
               Evaluation.detect_hallucination(
                 %Generation{
                   query: query,
                   context: context,
                   response: response
                 },
                 %{},
                 response_fn
               )
    end

    test "returns unchanged generation when halted? is true" do
      query = "an important query"
      context = "some context"
      response = "this is something completely unrelated"

      response_fn = fn _prompt, _params -> raise "unreachable" end

      generation = %Generation{
        query: query,
        context: context,
        response: response,
        halted?: true
      }

      assert generation == Evaluation.detect_hallucination(generation, %{}, response_fn)
    end

    test "emits start, stop, and exception telemetry events" do
      query = "an important query"
      context = "some context"
      response = "not relevant in this test"

      response_fn = fn _prompt, _params -> "not relevant" end

      generation = %Generation{query: query, context: context, response: response}

      ref =
        :telemetry_test.attach_event_handlers(self(), [
          [:rag, :detect_hallucination, :start],
          [:rag, :detect_hallucination, :stop],
          [:rag, :detect_hallucination, :exception]
        ])

      Evaluation.detect_hallucination(generation, %{}, response_fn)

      assert_received {[:rag, :detect_hallucination, :start], ^ref, _measurement, _meta}
      assert_received {[:rag, :detect_hallucination, :stop], ^ref, _measurement, _meta}

      crashing_response_fn = fn _prompt, _params -> raise "boom" end

      assert_raise RuntimeError, fn ->
        Evaluation.detect_hallucination(generation, %{}, crashing_response_fn)
      end

      assert_received {[:rag, :detect_hallucination, :exception], ^ref, _measurement, _meta}
    end
  end
end
