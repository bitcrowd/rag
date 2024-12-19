defmodule Rag.Generation do
  @moduledoc """
  Represents a generation.
  """
  alias Rag.Generation

  @type t :: %__MODULE__{
          query: String.t(),
          query_embedding: list(number()),
          retrieval_results: %{atom() => any},
          context: String.t(),
          context_sources: list(String.t()),
          prompt: String.t(),
          response: String.t(),
          evaluations: %{atom() => any}
        }

  @enforce_keys [:query]
  defstruct query: nil,
            query_embedding: nil,
            retrieval_results: %{},
            context: nil,
            context_sources: [],
            prompt: nil,
            response: nil,
            evaluations: %{}

  def new(query) when is_binary(query), do: %Generation{query: query}

  @spec put_retrieval_result(Generation.t(), key :: atom(), retrieval_result :: map()) ::
          Generation.t()
  def put_retrieval_result(%Generation{} = generation, key, retrieval_result),
    do: put_in(generation, [Access.key!(:retrieval_results), key], retrieval_result)

  @spec get_retrieval_result(Generation.t(), key :: atom()) :: any()
  def get_retrieval_result(%Generation{} = generation, key),
    do: Map.fetch!(generation.retrieval_results, key)
end
