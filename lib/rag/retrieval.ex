defmodule Rag.Retrieval do
  @moduledoc """
  Functions to transform retrieval results.
  """

  @doc """
  Calls `retrieval_function` with `rag_state` as only argument.
  `retrieval_function` must return the updated `rag_state`.
  The main purpose of `retrieve/2` is to emit telemetry events.
  """
  @spec retrieve(map(), (map() -> map())) :: map()
  def retrieve(rag_state, retrieval_function) do
    metadata = %{rag_state: rag_state}

    :telemetry.span([:rag, :retrieve], metadata, fn ->
      result = retrieval_function.(rag_state)

      {result, metadata}
    end)
  end

  @doc """
  Pops the retrieval result for each key in `retrieval_result_keys` from `rag_state`.
  Then, appends the retrieval result to the list at `output_key`.
  """
  @spec combine_retrieval_results(map(), list(atom()), atom()) :: map()
  def combine_retrieval_results(rag_state, retrieval_result_keys, output_key) do
    rag_state = Map.put_new(rag_state, output_key, [])

    for retrieval_result_key <- retrieval_result_keys, reduce: rag_state do
      state ->
        {retrieval_result, state} = Map.pop!(state, retrieval_result_key)

        Map.update!(state, output_key, fn combined_results ->
          combined_results ++ retrieval_result
        end)
    end
  end

  @doc """
  Deduplicates entries at `entries_key` in `rag_state`.
  Two entries are considered duplicates if they hold the same value at **all** `unique_by_keys`.
  In case of duplicates, the first entry is kept.
  """
  @spec deduplicate(map(), atom(), list(atom())) :: map()
  def deduplicate(rag_state, entries_key, unique_by_keys) do
    if unique_by_keys == [] do
      raise ArgumentError, "unique_by_keys must not be empty"
    end

    Map.update!(rag_state, entries_key, fn entries ->
      Enum.uniq_by(entries, &Map.take(&1, unique_by_keys))
    end)
  end
end
