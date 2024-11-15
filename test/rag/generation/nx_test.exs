defmodule Rag.Generation.NxTest do
  use ExUnit.Case
  use Mimic

  alias Rag.Generation

  describe "generate_response/2" do
    test "injects documents as context into the prompt" do
      expect(Nx.Serving, :batched_run, fn _serving, prompt -> %{results: [%{text: prompt}]} end)

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
               <|system|>
               You are a helpful assistant.</s>
               <|user|>
               Context information is below.
               ---------------------
               RAG stands for Retrieval Augmented Generation

               RAG systems are complex
               ---------------------
               Given the context information and no prior knowledge, answer the query.
               Query: What is RAG?
               Answer: </s>
               <|assistant|>
               """
             } =
               Generation.Nx.generate_response(%{
                 query: query,
                 query_results: query_results
               })
    end

    test "errors if query or query_results not present" do
      assert_raise MatchError, fn ->
        Generation.Nx.generate_response(%{query: "hello"})
      end

      assert_raise MatchError, fn ->
        Generation.Nx.generate_response(%{query_results: []})
      end
    end

    test "errors if query_results don't have document or source key" do
      query = "What is RAG?"

      query_results = [
        %{id: "first_document", text: "RAG stands for Retrieval Augmented Generation"}
      ]

      assert_raise KeyError, fn ->
        Generation.Nx.generate_response(%{query: query, query_results: query_results})
      end
    end
  end
end
