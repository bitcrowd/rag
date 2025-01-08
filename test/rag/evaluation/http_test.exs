defmodule Rag.Evaluation.HttpTest do
  use ExUnit.Case
  use Mimic

  alias Rag.Generation
  alias Rag.Evaluation
  alias Rag.Evaluation.Http.Params

  describe "evaluate_rag_triad/2" do
    test "takes a query, context, and response and returns an evaluation with scores and reasoning" do
      expect(Req, :post!, fn _url, _params ->
        %{
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
        }
      end)

      generation = %Generation{
        query: "What's with this?",
        context: "This is a test",
        response: "It's a test"
      }

      openai_params = Params.openai_params("gpt-4o-mini", "my_key")

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
             } = Evaluation.Http.evaluate_rag_triad(generation, openai_params)
    end

    test "emits start, stop, and exception telemetry events" do
      expect(Req, :post!, fn _url, _params ->
        %{
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
        }
      end)

      generation = %Generation{
        query: "What's with this?",
        context: "This is a test",
        response: "It's a test"
      }

      openai_params = Params.openai_params("gpt-4o-mini", "my_key")

      ref =
        :telemetry_test.attach_event_handlers(self(), [
          [:rag, :evaluate_rag_triad, :start],
          [:rag, :evaluate_rag_triad, :stop],
          [:rag, :evaluate_rag_triad, :exception]
        ])

      Evaluation.Http.evaluate_rag_triad(generation, openai_params)

      assert_received {[:rag, :evaluate_rag_triad, :start], ^ref, _measurement, _meta}
      assert_received {[:rag, :evaluate_rag_triad, :stop], ^ref, _measurement, _meta}

      expect(Req, :post!, fn _url, _params -> raise "boom" end)

      assert_raise RuntimeError, fn ->
        Evaluation.Http.evaluate_rag_triad(generation, openai_params)
      end

      assert_received {[:rag, :evaluate_rag_triad, :exception], ^ref, _measurement, _meta}
    end
  end
end
