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

    test "returns unchanged generation when halted? is true" do
      generation = %Generation{
        query: "What's with this?",
        context: "This is a test",
        response: "It's a test",
        halted?: true
      }

      openai_params = Params.openai_params("gpt-4o-mini", "my_key")

      assert generation == Evaluation.Http.evaluate_rag_triad(generation, openai_params)
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

    @tag :integration_test
    test "openai evaluation" do
      api_key = System.get_env("OPENAI_API_KEY")
      params = Params.openai_params("gpt-4o-mini", api_key)

      %Generation{query: "test?", response: _response} =
        Generation.Http.generate_response(%Generation{query: "test?", prompt: "prompt"}, params)
    end

    @tag :integration_test
    test "cohere evaluation" do
      api_key = System.get_env("COHERE_API_KEY")
      params = Params.cohere_params("command-r-plus-08-2024", api_key)

      %Generation{query: "test?", response: _response} =
        Generation.Http.generate_response(%Generation{query: "test?", prompt: "prompt"}, params)
    end
  end

  describe "detect_hallucination/2" do
    test "sets evaluation `:hallucination` to true if response does not equal \"YES\"" do
      expect(Req, :post!, fn _url, _params ->
        %{body: %{"choices" => [%{"index" => 0, "message" => %{"content" => "NO way"}}]}}
      end)

      query = "an important query"
      context = "some context"
      response = "this is something completely unrelated"
      params = Params.openai_params("openai_model", "somekey")

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

    test "sets evaluation `:hallucination` to false if response equals \"YES\"" do
      expect(Req, :post!, fn _url, _params ->
        %{body: %{"choices" => [%{"index" => 0, "message" => %{"content" => "YES"}}]}}
      end)

      query = "an important query"
      context = "some context"
      response = "this is something completely unrelated"
      params = Params.openai_params("openai_model", "somekey")

      assert %Generation{evaluations: %{hallucination: false}} =
               Evaluation.Http.detect_hallucination(
                 %Generation{
                   query: query,
                   context: context,
                   response: response
                 },
                 params
               )
    end

    test "returns unchanged generation when halted? is true" do
      query = "an important query"
      context = "some context"
      response = "this is something completely unrelated"
      params = Params.openai_params("openai_model", "somekey")

      generation = %Generation{
        query: query,
        context: context,
        response: response,
        halted?: true
      }

      assert generation == Evaluation.Http.detect_hallucination(generation, params)
    end

    test "emits start, stop, and exception telemetry events" do
      expect(Req, :post!, fn _url, _params ->
        %{body: %{"choices" => [%{"index" => 0, "message" => %{"content" => "not relevant"}}]}}
      end)

      query = "an important query"
      context = "some context"
      response = "not relevant in this test"
      params = Params.openai_params("openai_model", "somekey")

      generation = %Generation{query: query, context: context, response: response}

      ref =
        :telemetry_test.attach_event_handlers(self(), [
          [:rag, :detect_hallucination, :start],
          [:rag, :detect_hallucination, :stop],
          [:rag, :detect_hallucination, :exception]
        ])

      Evaluation.Http.detect_hallucination(generation, params)

      assert_received {[:rag, :detect_hallucination, :start], ^ref, _measurement, _meta}
      assert_received {[:rag, :detect_hallucination, :stop], ^ref, _measurement, _meta}

      expect(Req, :post!, fn _url, _params -> raise "boom" end)

      assert_raise RuntimeError, fn ->
        Evaluation.Http.detect_hallucination(generation, params)
      end

      assert_received {[:rag, :detect_hallucination, :exception], ^ref, _measurement, _meta}
    end

    @tag :integration_test
    test "openai evaluation" do
      api_key = System.get_env("OPENAI_API_KEY")
      params = Params.openai_params("gpt-4o-mini", api_key)

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
      params = Params.cohere_params("command-r-plus-08-2024", api_key)

      query = "When was Elixir 1.18.1 released?"
      context = "Elixir 1.18.1 was released on 2024-12-24"
      response = "It was released in October 2024"

      generation = %Generation{query: query, context: context, response: response}

      %Generation{evaluations: %{hallucination: true}} =
        Evaluation.Http.detect_hallucination(generation, params)
    end
  end
end
