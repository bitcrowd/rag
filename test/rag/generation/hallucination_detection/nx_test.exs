defmodule Rag.Generation.HallucinationDetection.NxTest do
  use ExUnit.Case
  use Mimic

  alias Rag.Generation.HallucinationDetection

  describe "detect_hallucination/2" do
    test "sets hallucination? to true if response does not equal \"YES\"" do
      expect(Nx.Serving, :batched_run, fn _serving, _prompt -> %{results: [%{text: "NO way"}]} end)

      query = "an important query"
      context = "some context"
      response = "this is something completely unrelated"

      assert %{hallucination?: true} =
               HallucinationDetection.Nx.detect_hallucination(%{
                 query: query,
                 context: context,
                 response: response
               })
    end

    test "sets hallucination? to false if response equals \"YES\"" do
      expect(Nx.Serving, :batched_run, fn _serving, _prompt ->
        %{results: [%{text: "YES"}]}
      end)

      query = "an important query"
      context = "some context"
      response = "this is something completely unrelated"

      assert %{hallucination?: false} =
               HallucinationDetection.Nx.detect_hallucination(%{
                 query: query,
                 context: context,
                 response: response
               })
    end

    test "errors if query, context, or response not present" do
      assert_raise MatchError, fn ->
        HallucinationDetection.Nx.detect_hallucination(%{
          context: "hello",
          response: "something"
        })
      end

      assert_raise MatchError, fn ->
        HallucinationDetection.Nx.detect_hallucination(%{query: "what?", response: "this"})
      end

      assert_raise MatchError, fn ->
        HallucinationDetection.Nx.detect_hallucination(%{
          query: "what?",
          context: "based on this"
        })
      end
    end
  end
end
