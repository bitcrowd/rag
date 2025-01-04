defmodule Rag.Retrieval do
  @moduledoc """
  Functions to transform retrieval results.
  """

  alias Rag.Generation

  @doc """
  Calls `retrieval_function` with `generation` as only argument.
  `retrieval_function` must return only the retrieval result.
  The main purpose of `retrieve/3` is to emit telemetry events.
  """
  @spec retrieve(
          Generation.t(),
          result_key :: atom(),
          (Generation.t() -> any())
        ) :: Generation.t()
  def retrieve(generation, result_key, retrieval_function) do
    metadata = %{generation: generation}

    :telemetry.span([:rag, :retrieve], metadata, fn ->
      result = retrieval_function.(generation)

      generation = Generation.put_retrieval_result(generation, result_key, result)

      {generation, %{metadata | generation: generation}}
    end)
  end

  @doc """
  Gets the retrieval result for each key in `retrieval_result_keys` from `generation`.
  Then, appends the retrieval result to the list at `output_key`.
  """
  @spec concatenate_retrieval_results(map(), list(atom()), atom()) :: map()
  def concatenate_retrieval_results(generation, retrieval_result_keys, output_key) do
    retrieval_results =
      Enum.flat_map(retrieval_result_keys, &Generation.get_retrieval_result(generation, &1))

    Generation.put_retrieval_result(generation, output_key, retrieval_results)
  end

  @doc """
  Gets the retrieval result for each key in `retrieval_result_keys` from `retrieval`.
  Then, applies [Reciprocal Rank Fusion](https://plg.uwaterloo.ca/~gvcormac/cormacksigir09-rrf.pdf) to combine the retrieval results into a single list at `output_key`.
  There is no guaranteed order for results with the same score.

  ## Options

   * `identity`: list of keys which define the identity of a result. Results with same `identity` will be fused.
  """
  @spec reciprocal_rank_fusion(
          Generation.t(),
          %{(key :: atom()) => weight :: integer()},
          output_key :: atom(),
          keyword(list(atom()))
        ) :: Generation.t()
  def reciprocal_rank_fusion(
        generation,
        retrieval_result_keys_and_weights,
        output_key,
        opts \\ []
      )

  def reciprocal_rank_fusion(_generation, retrieval_result_keys_and_weights, _output_key, _opts)
      when map_size(retrieval_result_keys_and_weights) == 0,
      do: raise(ArgumentError, "retrieval_result_keys_and_weights must not be empty")

  def reciprocal_rank_fusion(generation, retrieval_result_keys_and_weights, output_key, opts) do
    identity = Keyword.get(opts, :identity, [:id])

    # constant 60 comes from original paper
    k = 60
    number_retrievals = Enum.count(retrieval_result_keys_and_weights)

    rrf_result =
      retrieval_result_keys_and_weights
      |> Enum.flat_map(fn {key, weight} ->
        retrieval_result = Generation.get_retrieval_result(generation, key)

        retrieval_result
        |> rank_results(k, weight)
        |> normalize_score(number_retrievals, k)
      end)
      |> fuse_with_scores(identity)
      |> Enum.sort_by(& &1.score, :desc)
      |> Enum.map(& &1.result)

    Generation.put_retrieval_result(generation, output_key, rrf_result)
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
  Deduplicates entries at `entries_keys` in `retrieval_results` of `generation`.
  Two entries are considered duplicates if they hold the same value at **all** `unique_by_keys`.
  In case of duplicates, the first entry is kept.
  """
  @spec deduplicate(Generation.t(), atom(), list(atom())) :: Generation.t()
  def deduplicate(generation, entries_key, unique_by_keys) do
    if unique_by_keys == [] do
      raise ArgumentError, "unique_by_keys must not be empty"
    end

    retrieval_result =
      Map.fetch!(generation.retrieval_results, entries_key)
      |> Enum.uniq_by(&Map.take(&1, unique_by_keys))

    Generation.put_retrieval_result(generation, entries_key, retrieval_result)
  end
end
