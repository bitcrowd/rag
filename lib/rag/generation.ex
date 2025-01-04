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

  @spec put_query_embedding(Generation.t(), query_embedding :: list(number())) :: Generation.t()
  def put_query_embedding(%Generation{} = generation, query_embedding),
    do: %{generation | query_embedding: query_embedding}

  @spec put_retrieval_result(Generation.t(), key :: atom(), retrieval_result :: map()) ::
          Generation.t()
  def put_retrieval_result(%Generation{} = generation, key, retrieval_result),
    do: put_in(generation, [Access.key!(:retrieval_results), key], retrieval_result)

  @spec get_retrieval_result(Generation.t(), key :: atom()) :: any()
  def get_retrieval_result(%Generation{} = generation, key),
    do: Map.fetch!(generation.retrieval_results, key)

  @spec put_context(Generation.t(), context :: String.t()) :: Generation.t()
  def put_context(%Generation{} = generation, context) when is_binary(context),
    do: %{generation | context: context}

  @spec put_context_sources(Generation.t(), context_sources :: list(String.t())) :: Generation.t()
  def put_context_sources(%Generation{} = generation, context_sources)
      when is_list(context_sources),
      do: %{generation | context_sources: context_sources}

  @spec put_prompt(Generation.t(), prompt :: String.t()) :: Generation.t()
  def put_prompt(%Generation{} = generation, prompt) when is_binary(prompt),
    do: %{generation | prompt: prompt}

  @spec put_response(Generation.t(), response :: String.t()) :: Generation.t()
  def put_response(%Generation{} = generation, response) when is_binary(response),
    do: %{generation | response: response}

  @spec put_evaluation(Generation.t(), key :: atom(), evaluation :: any()) :: Generation.t()
  def put_evaluation(%Generation{} = generation, key, evaluation),
    do: put_in(generation, [Access.key!(:evaluations), key], evaluation)

  @spec get_evaluation(Generation.t(), key :: atom()) :: any()
  def get_evaluation(%Generation{} = generation, key),
    do: Map.fetch!(generation.evaluations, key)
end
