defmodule Rag.RetrievalTest do
  use ExUnit.Case
  use Mimic

  alias Rag.Generation
  alias Rag.Retrieval

  describe "retrieve/3" do
    test "calls the retrieval_function and returns its result" do
      fun = fn state ->
        assert state == %Generation{query: "query?"}
        "hello, you called me"
      end

      generation = %Generation{query: "query?"}

      assert Rag.Retrieval.retrieve(generation, :result, &fun.(&1)) == %Generation{
               query: "query?",
               retrieval_results: %{
                 result: "hello, you called me"
               }
             }
    end

    test "returns unchanged generation when halted? is true" do
      generation = %Generation{query: "query?", halted?: true}

      assert generation == Rag.Retrieval.retrieve(generation, :result, fn _ -> "ignored" end)
    end

    test "emits start, stop, and exception events" do
      fun = fn state ->
        assert state == %Generation{query: "query?"}
        "hello, you called me"
      end

      generation = %Generation{query: "query?"}

      ref =
        :telemetry_test.attach_event_handlers(self(), [
          [:rag, :retrieve, :start],
          [:rag, :retrieve, :stop],
          [:rag, :retrieve, :exception]
        ])

      Rag.Retrieval.retrieve(generation, :out, &fun.(&1))

      assert_received {[:rag, :retrieve, :start], ^ref, _measurement, _meta}
      assert_received {[:rag, :retrieve, :stop], ^ref, _measurement, _meta}

      failing_function = fn _state -> raise "boom" end

      assert_raise RuntimeError, fn ->
        Rag.Retrieval.retrieve(generation, :out, &failing_function.(&1))
      end

      assert_received {[:rag, :retrieve, :exception], ^ref, _measurement, _meta}
    end
  end

  describe "concatenate_retrieval_results/3" do
    test "pops the results at retrieval_result_keys and combines them into a list at output_key" do
      foo_results = [%{id: 0, text: "something"}, %{id: 1, text: "something else"}]
      bar_results = [%{id: 0, text: "bar"}, %{id: 1, text: "bar else"}]

      generation = %Generation{
        query: "query",
        retrieval_results: %{foo: foo_results, bar: bar_results}
      }

      retrieval_result_keys = [:foo, :bar]
      output_key = :combined_result

      output_generation =
        Retrieval.concatenate_retrieval_results(generation, retrieval_result_keys, output_key)

      for key <- retrieval_result_keys do
        refute Map.has_key?(output_generation, key)
      end

      assert Generation.get_retrieval_result(output_generation, output_key) ==
               foo_results ++ bar_results
    end

    test "overwrites existing results at output_key" do
      existing_results = [%{id: 0, text: "existing"}]
      new_results = [%{id: 1001, text: "new result"}]

      generation = %Generation{
        query: "query",
        retrieval_results: %{results: existing_results, new: new_results}
      }

      output_generation = Retrieval.concatenate_retrieval_results(generation, [:new], :results)

      assert Generation.get_retrieval_result(output_generation, :results) == new_results
    end

    test "errors if one of retrieval_result_keys is not in generation" do
      generation = %Generation{query: "hello"}

      assert_raise KeyError, fn ->
        Retrieval.concatenate_retrieval_results(generation, [:foo], :results)
      end
    end

    test "returns unchanged generation when halted? is true" do
      generation = %Generation{query: "hello", halted?: true}

      assert generation == Retrieval.concatenate_retrieval_results(generation, [:foo], :results)
    end
  end

  describe "reciprocal_rank_fusion/3" do
    test "pops the results at retrieval_result_keys and fuses the results based on the ranking of items in the results" do
      foo_results = [%{id: 0, text: "something"}, %{id: 1, text: "something else"}]
      bar_results = [%{id: 2, text: "bar"}, %{id: 3, text: "bar else"}]

      generation = %Generation{
        query: "query",
        retrieval_results: %{foo: foo_results, bar: bar_results}
      }

      retrieval_result_keys_and_weights = %{foo: 1, bar: 1}
      output_key = :rrf_result

      output_generation =
        Retrieval.reciprocal_rank_fusion(
          generation,
          retrieval_result_keys_and_weights,
          output_key
        )

      for {key, _weight} <- retrieval_result_keys_and_weights do
        refute Map.has_key?(output_generation, key)
      end

      assert Generation.get_retrieval_result(output_generation, output_key) == [
               %{id: 0, text: "something"},
               %{id: 2, text: "bar"},
               %{id: 1, text: "something else"},
               %{id: 3, text: "bar else"}
             ]
    end

    test "sums scores of same document in different result lists" do
      foo_results = [%{id: 0, text: "foo"}, %{id: 1, text: "important"}]
      bar_results = [%{id: 2, text: "bar"}, %{id: 1, text: "important"}]

      generation = %Generation{
        query: "query",
        retrieval_results: %{foo: foo_results, bar: bar_results}
      }

      retrieval_result_keys_and_weights = %{foo: 1, bar: 1}
      output_key = :rrf_result

      output_generation =
        Retrieval.reciprocal_rank_fusion(
          generation,
          retrieval_result_keys_and_weights,
          output_key,
          identify: :id
        )

      for {key, _weight} <- retrieval_result_keys_and_weights do
        refute Map.has_key?(output_generation, key)
      end

      assert Generation.get_retrieval_result(output_generation, output_key) == [
               %{id: 1, text: "important"},
               %{id: 0, text: "foo"},
               %{id: 2, text: "bar"}
             ]
    end

    test "takes weight into account" do
      foo_results = [%{id: 0, text: "something"}, %{id: 1, text: "something else"}]
      bar_results = [%{id: 0, text: "bar"}, %{id: 1, text: "bar else"}]

      generation = %Generation{
        query: "query",
        retrieval_results: %{foo: foo_results, bar: bar_results}
      }

      retrieval_result_keys_and_weights = %{foo: 1, bar: 2}
      output_key = :rrf_result

      output_generation =
        Retrieval.reciprocal_rank_fusion(
          generation,
          retrieval_result_keys_and_weights,
          output_key,
          identity: [:text]
        )

      assert Generation.get_retrieval_result(output_generation, output_key) == [
               %{id: 0, text: "bar"},
               %{id: 1, text: "bar else"},
               %{id: 0, text: "something"},
               %{id: 1, text: "something else"}
             ]
    end

    test "overwrites existing results at output_key" do
      existing_results = [%{id: 0, text: "existing"}]
      new_results = [%{id: 1001, text: "new result"}]

      generation = %Generation{
        query: "query",
        retrieval_results: %{results: existing_results, new: new_results}
      }

      output_generation = Retrieval.reciprocal_rank_fusion(generation, %{new: 1}, :results)

      assert Generation.get_retrieval_result(output_generation, :results) == new_results
    end

    test "errors if one of retrieval_result_keys is not in generation" do
      generation = %Generation{query: "hello"}

      assert_raise KeyError, fn ->
        Retrieval.reciprocal_rank_fusion(generation, %{foo: 1}, :results)
      end
    end

    test "errors if passed empty list of keys and weights for retrieval results" do
      generation = %Generation{query: "hello"}

      assert_raise ArgumentError, fn ->
        Retrieval.reciprocal_rank_fusion(generation, %{}, :results)
      end
    end

    test "returns unchanged generation when halted? is true" do
      generation = %Generation{query: "hello", halted?: true}

      assert generation == Retrieval.reciprocal_rank_fusion(generation, %{foo: 1}, :results)
    end
  end

  describe "deduplicate_results/3" do
    test "keeps only first result for entries with same values at all unique_by_keys" do
      results = [%{id: 0, value: "hello"}, %{id: 1, value: "hola"}, %{id: 0, value: "something"}]
      generation = %Generation{query: "query", retrieval_results: %{results: results}}

      assert Retrieval.deduplicate(generation, :results, [:id]) == %Generation{
               query: "query",
               retrieval_results: %{
                 results: [%{id: 0, value: "hello"}, %{id: 1, value: "hola"}]
               }
             }
    end

    test "errors if one of entries_key is not in generation" do
      generation = %Generation{query: "hello"}

      assert_raise KeyError, fn ->
        Retrieval.deduplicate(generation, :results, [:foo])
      end
    end

    test "errors if unique_by_keys is empty" do
      generation = %Generation{query: "hello"}

      assert_raise ArgumentError, fn ->
        Retrieval.deduplicate(generation, :text, [])
      end
    end

    test "returns unchanged generation when halted? is true" do
      generation = %Generation{query: "hello", halted?: true}

      assert generation == Retrieval.deduplicate(generation, :results, [:foo])
    end
  end
end
