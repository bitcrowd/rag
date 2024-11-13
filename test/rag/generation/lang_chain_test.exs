defmodule Rag.Generation.LangChainTest do
  use ExUnit.Case
  use Mimic

  alias Rag.Generation
  alias LangChain.Chains.LLMChain
  alias LangChain.ChatModels.ChatOpenAI

  @chain LLMChain.new!(%{llm: ChatOpenAI.new!(%{model: "gpt-4"})})

  describe "generate_response/2" do
    test "injects documents as context into the prompt" do
      LLMChain
      |> expect(:add_message, fn chain, message ->
        call_original(LLMChain, :add_message, [chain, message])
      end)
      |> expect(:run, fn chain ->
        {:ok, chain, %{content: chain.last_message.content}}
      end)

      query = "What is RAG?"

      query_results = [
        %{source: "first_document", document: "RAG stands for Retrieval Augmented Generation"},
        %{source: "second_document", document: "RAG systems are complex"}
      ]

      assert %{
               context:
                 "RAG stands for Retrieval Augmented Generation\n\nRAG systems are complex",
               context_sources: ["first_document", "second_document"],
               response: """
               Context information is below.
               ---------------------
               RAG stands for Retrieval Augmented Generation

               RAG systems are complex
               ---------------------
               Given the context information and no prior knowledge, answer the query.
               Query: What is RAG?
               Answer:
               """
             } =
               Generation.LangChain.generate_response(
                 %{
                   query: query,
                   query_results: query_results
                 },
                 @chain
               )
    end

    test "errors if query or query_results not present" do
      assert_raise FunctionClauseError, fn ->
        Generation.LangChain.generate_response(%{query: "hello"}, @chain)
      end

      assert_raise FunctionClauseError, fn ->
        Generation.LangChain.generate_response(%{query_results: []}, @chain)
      end
    end

    test "errors if query_results don't have document or source key" do
      query = "What is RAG?"

      query_results = [
        %{id: "first_document", text: "RAG stands for Retrieval Augmented Generation"}
      ]

      assert_raise KeyError, fn ->
        Generation.LangChain.generate_response(
          %{query: query, query_results: query_results},
          @chain
        )
      end
    end
  end
end
