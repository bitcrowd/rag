defmodule Rag.Generation.HallucinationDetection.LangChainTest do
  use ExUnit.Case
  use Mimic

  alias Rag.Generation.HallucinationDetection
  alias LangChain.Chains.LLMChain
  alias LangChain.ChatModels.ChatOpenAI

  @chain LLMChain.new!(%{llm: ChatOpenAI.new!(%{model: "gpt-4"})})

  describe "detect_hallucination/2" do
    test "sets hallucination? to true if response does not equal \"YES\"" do
      LLMChain
      |> expect(:add_message, fn chain, message ->
        call_original(LLMChain, :add_message, [chain, message])
      end)
      |> expect(:run, fn chain ->
        {:ok, chain, %{content: "NO way"}}
      end)

      query = "an important query"
      context = "some context"
      response = "this is something completely unrelated"

      assert %{hallucination?: true} =
               HallucinationDetection.LangChain.detect_hallucination(
                 %{
                   query: query,
                   context: context,
                   response: response
                 },
                 @chain
               )
    end

    test "sets hallucination? to false if response equals \"YES\"" do
      LLMChain
      |> expect(:add_message, fn chain, message ->
        call_original(LLMChain, :add_message, [chain, message])
      end)
      |> expect(:run, fn chain ->
        {:ok, chain, %{content: "YES"}}
      end)

      query = "an important query"
      context = "some context"
      response = "this is something completely unrelated"

      assert %{hallucination?: false} =
               HallucinationDetection.LangChain.detect_hallucination(
                 %{
                   query: query,
                   context: context,
                   response: response
                 },
                 @chain
               )
    end

    test "errors if query, context, or response not present" do
      assert_raise MatchError, fn ->
        HallucinationDetection.LangChain.detect_hallucination(
          %{
            context: "hello",
            response: "something"
          },
          @chain
        )
      end

      assert_raise MatchError, fn ->
        HallucinationDetection.LangChain.detect_hallucination(
          %{query: "what?", response: "this"},
          @chain
        )
      end

      assert_raise MatchError, fn ->
        HallucinationDetection.LangChain.detect_hallucination(
          %{
            query: "what?",
            context: "based on this"
          },
          @chain
        )
      end
    end
  end
end
