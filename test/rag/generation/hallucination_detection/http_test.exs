defmodule Rag.Generation.HallucinationDetection.HttpTest do
  use ExUnit.Case
  use Mimic

  alias Rag.Generation
  alias Rag.Generation.HallucinationDetection
  alias Rag.Generation.Http.Params

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
               HallucinationDetection.Http.detect_hallucination(
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
               HallucinationDetection.Http.detect_hallucination(
                 %Generation{
                   query: query,
                   context: context,
                   response: response
                 },
                 params
               )
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

      HallucinationDetection.Http.detect_hallucination(generation, params)

      assert_received {[:rag, :detect_hallucination, :start], ^ref, _measurement, _meta}
      assert_received {[:rag, :detect_hallucination, :stop], ^ref, _measurement, _meta}

      expect(Req, :post!, fn _url, _params -> raise "boom" end)

      assert_raise RuntimeError, fn ->
        HallucinationDetection.Http.detect_hallucination(generation, params)
      end

      assert_received {[:rag, :detect_hallucination, :exception], ^ref, _measurement, _meta}
    end
  end
end
