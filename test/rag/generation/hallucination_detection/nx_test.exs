defmodule Rag.Generation.HallucinationDetection.NxTest do
  use ExUnit.Case
  use Mimic

  alias Rag.Generation
  alias Rag.Generation.HallucinationDetection

  describe "detect_hallucination/2" do
    test "sets evaluation `:hallucination` to true if response does not equal \"YES\"" do
      expect(Nx.Serving, :batched_run, fn _serving, _prompt -> %{results: [%{text: "NO way"}]} end)

      query = "an important query"
      context = "some context"
      response = "this is something completely unrelated"

      assert %Generation{evaluations: %{hallucination: true}} =
               HallucinationDetection.Nx.detect_hallucination(%Generation{
                 query: query,
                 context: context,
                 response: response
               })
    end

    test "sets evaluation `:hallucination` to false if response equals \"YES\"" do
      expect(Nx.Serving, :batched_run, fn _serving, _prompt ->
        %{results: [%{text: "YES"}]}
      end)

      query = "an important query"
      context = "some context"
      response = "this is something completely unrelated"

      assert %Generation{evaluations: %{hallucination: false}} =
               HallucinationDetection.Nx.detect_hallucination(%Generation{
                 query: query,
                 context: context,
                 response: response
               })
    end

    test "emits start, stop, and exception telemetry events" do
      expect(Nx.Serving, :batched_run, fn _serving, _prompt ->
        %{results: [%{text: "not relevant in this test"}]}
      end)

      query = "an important query"
      context = "some context"
      response = "not relevant in this test"

      generation = %Generation{query: query, context: context, response: response}

      ref =
        :telemetry_test.attach_event_handlers(self(), [
          [:rag, :detect_hallucination, :start],
          [:rag, :detect_hallucination, :stop],
          [:rag, :detect_hallucination, :exception]
        ])

      HallucinationDetection.Nx.detect_hallucination(generation)

      assert_received {[:rag, :detect_hallucination, :start], ^ref, _measurement, _meta}
      assert_received {[:rag, :detect_hallucination, :stop], ^ref, _measurement, _meta}

      expect(Nx.Serving, :batched_run, fn _serving, _prompt -> raise "boom" end)

      assert_raise RuntimeError, fn ->
        HallucinationDetection.Nx.detect_hallucination(generation)
      end

      assert_received {[:rag, :detect_hallucination, :exception], ^ref, _measurement, _meta}
    end
  end
end
