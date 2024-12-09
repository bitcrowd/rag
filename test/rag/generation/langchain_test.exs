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

      rag_state = %{prompt: prompt}

      assert %{response: "a response"} = Generation.LangChain.generate_response(rag_state, @chain)
    end

    test "errors if prompt not present" do
      assert_raise MatchError, fn ->
        Generation.LangChain.generate_response(%{}, @chain)
      end
    end
  end
end
