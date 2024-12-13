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
  @spec concatenate_retrieval_results(map(), list(atom()), atom()) :: map()
  def concatenate_retrieval_results(rag_state, retrieval_result_keys, output_key) do
    rag_state = Map.put(rag_state, output_key, [])

    for retrieval_result_key <- retrieval_result_keys, reduce: rag_state do
      state ->
        {retrieval_result, state} = Map.pop!(state, retrieval_result_key)

        Map.update!(state, output_key, fn combined_results ->
          combined_results ++ retrieval_result
        end)
    end
  end

  @doc """
  Pops the retrieval result for each key in `retrieval_result_keys` from `rag_state`.
  Then, applies [Reciprocal Rank Fusion](https://plg.uwaterloo.ca/~gvcormac/cormacksigir09-rrf.pdf) to combine the retrieval results into a single list at `output_key`.
  There is no guaranteed order for results with the same score.

  Options:
   * `identity`: list of keys which define the identity of a result. Results with same `identity` will be fused.
  """
  @spec reciprocal_rank_fusion(
          map(),
          %{(key :: atom()) => weight :: integer()},
          atom(),
          keyword(list(atom()))
        ) ::
          map()
  def reciprocal_rank_fusion(rag_state, retrieval_result_keys_and_weights, output_key, opts \\ [])

  def reciprocal_rank_fusion(_rag_state, retrieval_result_keys_and_weights, _output_key, _opts)
      when map_size(retrieval_result_keys_and_weights) == 0,
      do: raise(ArgumentError, "retrieval_result_keys_and_weights must not be empty")

  def reciprocal_rank_fusion(rag_state, retrieval_result_keys_and_weights, output_key, opts) do
    identity = Keyword.get(opts, :identity, [:id])

    rag_state = Map.put(rag_state, output_key, [])

    # constant 60 comes from original paper
    k = 60
    number_retrievals = Enum.count(retrieval_result_keys_and_weights)

    rrf_results =
      retrieval_result_keys_and_weights
      |> Enum.flat_map(fn {key, weight} ->
        retrieval_result = Map.fetch!(rag_state, key)

        retrieval_result
        |> rank_results(k, weight)
        |> normalize_score(number_retrievals, k)
      end)
      |> fuse_with_scores(identity)
      |> Enum.sort_by(& &1.score, :desc)
      |> Enum.map(& &1.result)

    rag_state
    |> Map.put(output_key, rrf_results)
    |> Map.drop(Map.keys(retrieval_result_keys_and_weights))
  end

  defp fuse_with_scores(results, identity) do
    for {score, result} <- results, reduce: %{} do
      identity_scores_result ->
        result_identity = Map.take(result, identity)

        Map.update(
          identity_scores_result,
          result_identity,
          %{score: score, result: result},
          fn %{score: existing_score, result: result} ->
            %{score: existing_score + score, result: result}
          end
        )
    end
    |> Map.values()
  end

  defp rank_results(results, k, weight) do
    len = length(results)

    for {result, rank} <- Enum.with_index(results) do
      score = weight * len / (k + rank)

      {score, result}
    end
  end

  defp normalize_score(results, number_retrievals, k) do
    for {score, result} <- results do
      score = score / (number_retrievals / k)
      {score, result}
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
