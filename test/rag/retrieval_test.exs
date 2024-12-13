defmodule Rag.RetrievalTest do
  use ExUnit.Case
  use Mimic

  alias Rag.Retrieval

  describe "retrieve/2" do
    test "calls the function passed as second argument and returns its result" do
      fun = fn state ->
        assert state == %{test: "test"}
        Map.put(state, :result, "hello, you called me")
      end

      rag_state = %{test: "test"}

      assert Rag.Retrieval.retrieve(rag_state, &fun.(&1)) == %{
               test: "test",
               result: "hello, you called me"
             }
    end

    test "emits start, stop, and exception events" do
      fun = fn state ->
        assert state == %{test: "test"}
        Map.put(state, :result, "hello, you called me")
      end

      rag_state = %{test: "test"}

      ref =
        :telemetry_test.attach_event_handlers(self(), [
          [:rag, :retrieve, :start],
          [:rag, :retrieve, :stop],
          [:rag, :retrieve, :exception]
        ])

      Rag.Retrieval.retrieve(rag_state, &fun.(&1))

      assert_received {[:rag, :retrieve, :start], ^ref, _measurement, _meta}
      assert_received {[:rag, :retrieve, :stop], ^ref, _measurement, _meta}

      failing_function = fn _state -> raise "boom" end

      assert_raise RuntimeError, fn ->
        Rag.Retrieval.retrieve(rag_state, &failing_function.(&1))
      end

      assert_received {[:rag, :retrieve, :exception], ^ref, _measurement, _meta}
    end
  end

  describe "concatenate_retrieval_results/3" do
    test "pops the results at retrieval_result_keys and combines them into a list at output_key" do
      foo_results = [%{id: 0, text: "something"}, %{id: 1, text: "something else"}]
      bar_results = [%{id: 0, text: "bar"}, %{id: 1, text: "bar else"}]

      rag_state = %{foo: foo_results, bar: bar_results}

      retrieval_result_keys = [:foo, :bar]
      output_key = :combined_result

      output_rag_state =
        Retrieval.concatenate_retrieval_results(rag_state, retrieval_result_keys, output_key)

      for key <- retrieval_result_keys do
        refute Map.has_key?(output_rag_state, key)
      end

      assert Map.fetch!(output_rag_state, output_key) == foo_results ++ bar_results
    end

    test "overwrites existing results at output_key" do
      existing_results = [%{id: 0, text: "existing"}]
      new_results = [%{id: 1001, text: "new result"}]
      rag_state = %{results: existing_results, new: new_results}

      output_rag_state = Retrieval.concatenate_retrieval_results(rag_state, [:new], :results)

      assert Map.fetch!(output_rag_state, :results) == new_results
    end

    test "errors if one of retrieval_result_keys is not in rag_state" do
      rag_state = %{text: "hello"}

      assert_raise KeyError, fn ->
        Retrieval.concatenate_retrieval_results(rag_state, [:foo], :results)
      end
    end
  end

  describe "reciprocal_rank_fusion/3" do
    test "pops the results at retrieval_result_keys and fuses the results based on the ranking of items in the results" do
      foo_results = [%{id: 0, text: "something"}, %{id: 1, text: "something else"}]
      bar_results = [%{id: 2, text: "bar"}, %{id: 3, text: "bar else"}]

      rag_state = %{foo: foo_results, bar: bar_results}

      retrieval_result_keys_and_weights = %{foo: 1, bar: 1}
      output_key = :rrf_result

      output_rag_state =
        Retrieval.reciprocal_rank_fusion(rag_state, retrieval_result_keys_and_weights, output_key)

      for {key, _weight} <- retrieval_result_keys_and_weights do
        refute Map.has_key?(output_rag_state, key)
      end

      assert Map.fetch!(output_rag_state, output_key) == [
               %{id: 0, text: "something"},
               %{id: 2, text: "bar"},
               %{id: 1, text: "something else"},
               %{id: 3, text: "bar else"}
             ]
    end

    test "sums scores of same document in different result lists" do
      foo_results = [%{id: 0, text: "foo"}, %{id: 1, text: "important"}]
      bar_results = [%{id: 2, text: "bar"}, %{id: 1, text: "important"}]

      rag_state = %{foo: foo_results, bar: bar_results}

      retrieval_result_keys_and_weights = %{foo: 1, bar: 1}
      output_key = :rrf_result

      output_rag_state =
        Retrieval.reciprocal_rank_fusion(rag_state, retrieval_result_keys_and_weights, output_key,
          identify: :id
        )

      for {key, _weight} <- retrieval_result_keys_and_weights do
        refute Map.has_key?(output_rag_state, key)
      end

      assert Map.fetch!(output_rag_state, output_key) == [
               %{id: 1, text: "important"},
               %{id: 0, text: "foo"},
               %{id: 2, text: "bar"}
             ]
    end

    test "takes weight into account" do
      foo_results = [%{id: 0, text: "something"}, %{id: 1, text: "something else"}]
      bar_results = [%{id: 0, text: "bar"}, %{id: 1, text: "bar else"}]

      rag_state = %{foo: foo_results, bar: bar_results}

      retrieval_result_keys_and_weights = %{foo: 1, bar: 2}
      output_key = :rrf_result

      output_rag_state =
        Retrieval.reciprocal_rank_fusion(rag_state, retrieval_result_keys_and_weights, output_key,
          identity: [:text]
        )

      assert Map.fetch!(output_rag_state, output_key) == [
               %{id: 0, text: "bar"},
               %{id: 1, text: "bar else"},
               %{id: 0, text: "something"},
               %{id: 1, text: "something else"}
             ]
    end

    test "overwrites existing results at output_key" do
      existing_results = [%{id: 0, text: "existing"}]
      new_results = [%{id: 1001, text: "new result"}]
      rag_state = %{results: existing_results, new: new_results}

      output_rag_state = Retrieval.reciprocal_rank_fusion(rag_state, %{new: 1}, :results)

      assert Map.fetch!(output_rag_state, :results) == new_results
    end

    test "errors if one of retrieval_result_keys is not in rag_state" do
      rag_state = %{text: "hello"}

      assert_raise KeyError, fn ->
        Retrieval.reciprocal_rank_fusion(rag_state, %{foo: 1}, :results)
      end
    end

    test "errors if passed empty list of keys and weights for retrieval results" do
      rag_state = %{text: "hello"}

      assert_raise ArgumentError, fn ->
        Retrieval.reciprocal_rank_fusion(rag_state, %{}, :results)
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
