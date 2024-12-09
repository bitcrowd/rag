defmodule Rag.RetrievalTest do
  use ExUnit.Case
  use Mimic

  alias Rag.Retrieval

  describe "combine_retrieval_results/3" do
    test "pops the results at retrieval_result_keys and combines them into a list at output_key" do
      foo_results = [%{id: 0, text: "something"}, %{id: 1, text: "something else"}]
      bar_results = [%{id: 0, text: "bar"}, %{id: 1, text: "bar else"}]

      rag_state = %{foo: foo_results, bar: bar_results}

      retrieval_result_keys = [:foo, :bar]
      output_key = :combined_result

      output_rag_state =
        Retrieval.combine_retrieval_results(rag_state, retrieval_result_keys, output_key)

      for key <- retrieval_result_keys do
        refute Map.has_key?(output_rag_state, key)
      end

      assert Map.fetch!(output_rag_state, output_key) == foo_results ++ bar_results
    end

    test "keeps existing results at output_key" do
      existing_results = [%{id: 0, text: "existing"}]
      new_results = [%{id: 1001, text: "new result"}]
      rag_state = %{results: existing_results, new: new_results}

      output_rag_state = Retrieval.combine_retrieval_results(rag_state, [:new], :results)

      assert Map.fetch!(output_rag_state, :results) == existing_results ++ new_results
    end

    test "errors if one of retrieval_result_keys is not in rag_state" do
      rag_state = %{text: "hello"}

      assert_raise KeyError, fn ->
        Retrieval.combine_retrieval_results(rag_state, [:foo], :results)
      end
    end
  end

  describe "deduplicate_results/3" do
    test "keeps only first result for entries with same values at all unique_by_keys" do
      results = [%{id: 0, value: "hello"}, %{id: 1, value: "hola"}, %{id: 0, value: "something"}]
      rag_state = %{results: results}

      assert Retrieval.deduplicate(rag_state, :results, [:id]) == %{
               results: [%{id: 0, value: "hello"}, %{id: 1, value: "hola"}]
             }
    end

    test "errors if one of entries_key is not in rag_state" do
      rag_state = %{text: "hello"}

      assert_raise KeyError, fn ->
        Retrieval.deduplicate(rag_state, :results, [:foo])
      end
    end

    test "errors if unique_by_keys is empty" do
      rag_state = %{text: "hello"}

      assert_raise ArgumentError, fn ->
        Retrieval.deduplicate(rag_state, :text, [])
      end
    end
  end
end
