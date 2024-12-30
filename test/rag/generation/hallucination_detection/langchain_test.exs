defmodule Rag.Generation.HallucinationDetection.LangChainTest do
  use ExUnit.Case
  use Mimic

  alias Rag.Generation
  alias Rag.Generation.HallucinationDetection
  alias LangChain.Chains.LLMChain
  alias LangChain.ChatModels.ChatOpenAI

  @chain LLMChain.new!(%{llm: ChatOpenAI.new!(%{model: "gpt-4"})})

  describe "detect_hallucination/2" do
    test "sets evaluation `:hallucination` to true if response does not equal \"YES\"" do
      LLMChain
      |> expect(:add_message, fn chain, message ->
        call_original(LLMChain, :add_message, [chain, message])
      end)
      |> expect(:run, fn chain ->
        {:ok, %{chain | last_message: %LangChain.Message{content: "NO way", role: :assistant}}}
      end)

      query = "an important query"
      context = "some context"
      response = "this is something completely unrelated"

      assert %Generation{evaluations: %{hallucination: true}} =
               HallucinationDetection.LangChain.detect_hallucination(
                 %Generation{
                   query: query,
                   context: context,
                   response: response
                 },
                 @chain
               )
    end

    test "sets evaluation `:hallucination` to false if response equals \"YES\"" do
      LLMChain
      |> expect(:add_message, fn chain, message ->
        call_original(LLMChain, :add_message, [chain, message])
      end)
      |> expect(:run, fn chain ->
        {:ok, %{chain | last_message: %LangChain.Message{content: "YES", role: :assistant}}}
      end)

      query = "an important query"
      context = "some context"
      response = "this is something completely unrelated"

      assert %Generation{evaluations: %{hallucination: false}} =
               HallucinationDetection.LangChain.detect_hallucination(
                 %Generation{
                   query: query,
                   context: context,
                   response: response
                 },
                 @chain
               )
    end

    test "emits start, stop, and exception telemetry events" do
      LLMChain
      |> expect(:add_message, fn chain, message ->
        call_original(LLMChain, :add_message, [chain, message])
      end)
      |> expect(:run, fn chain ->
        {:ok,
         %{
           chain
           | last_message: %LangChain.Message{
               content: "not relevant in this test",
               role: :assistant
             }
         }}
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

      HallucinationDetection.LangChain.detect_hallucination(generation, @chain)

      assert_received {[:rag, :detect_hallucination, :start], ^ref, _measurement, _meta}
      assert_received {[:rag, :detect_hallucination, :stop], ^ref, _measurement, _meta}

      LLMChain
      |> expect(:add_message, fn chain, message ->
        call_original(LLMChain, :add_message, [chain, message])
      end)
      |> expect(:run, fn _chain -> raise "boom" end)

      assert_raise RuntimeError, fn ->
        HallucinationDetection.LangChain.detect_hallucination(generation, @chain)
      end

      assert_received {[:rag, :detect_hallucination, :exception], ^ref, _measurement, _meta}
    end
  end
end
