defmodule Rag.Generation.LangChainTest do
  use ExUnit.Case
  use Mimic

  alias Rag.Generation
  alias LangChain.Chains.LLMChain
  alias LangChain.ChatModels.ChatOpenAI

  @chain LLMChain.new!(%{llm: ChatOpenAI.new!(%{model: "gpt-4"})})

  describe "generate_response/2" do
    test "adds prompt as message to `chain` and runs it to generate a response" do
      LLMChain
      |> expect(:add_message, fn chain, message ->
        assert chain == @chain
        assert %LangChain.Message{content: "a prompt", role: :user} = message
        call_original(LLMChain, :add_message, [chain, message])
      end)
      |> expect(:run, fn chain ->
        {:ok, chain, %{content: "a response"}}
      end)

      prompt = "a prompt"

      generation = %Generation{query: "query", prompt: prompt}

      assert %{response: "a response"} =
               Generation.LangChain.generate_response(generation, @chain)
    end

    test "emits start, stop, and exception telemetry events" do
      LLMChain
      |> expect(:add_message, fn chain, message ->
        assert chain == @chain
        assert %LangChain.Message{content: "a prompt", role: :user} = message
        call_original(LLMChain, :add_message, [chain, message])
      end)
      |> expect(:run, fn chain ->
        {:ok, chain, %{content: "a response"}}
      end)

      prompt = "a prompt"

      generation = %Generation{query: "query", prompt: prompt}

      ref =
        :telemetry_test.attach_event_handlers(self(), [
          [:rag, :generate_response, :start],
          [:rag, :generate_response, :stop],
          [:rag, :generate_response, :exception]
        ])

      Generation.LangChain.generate_response(generation, @chain)

      assert_received {[:rag, :generate_response, :start], ^ref, _measurement, _meta}
      assert_received {[:rag, :generate_response, :stop], ^ref, _measurement, _meta}

      LLMChain
      |> expect(:add_message, fn chain, message ->
        assert chain == @chain
        assert %LangChain.Message{content: "a prompt", role: :user} = message
        call_original(LLMChain, :add_message, [chain, message])
      end)
      |> expect(:run, fn _chain ->
        raise "boom"
      end)

      assert_raise RuntimeError, fn ->
        Generation.LangChain.generate_response(generation, @chain)
      end

      assert_received {[:rag, :generate_response, :exception], ^ref, _measurement, _meta}
    end
  end
end
