defmodule Rag.Generation do
  @moduledoc """
  Functions to generate a response and helpers to work with a generation struct.
  """
  alias Rag.Generation

  @type embedding :: list(number())
  @type response_function :: (String.t(), keyword() -> String.t())
  @type provider :: struct()
  @type stream :: boolean()

  @typedoc """
  Represents a generation, the main datastructure in `rag`.
  """
  @type t :: %__MODULE__{
          query: String.t() | nil,
          query_embedding: embedding() | nil,
          retrieval_results: %{optional(atom()) => any()},
          context: String.t() | nil,
          context_sources: list(String.t()),
          prompt: String.t() | nil,
          response: String.t() | Stream | Enum.t() | nil,
          evaluations: %{optional(atom()) => any()},
          halted?: boolean(),
          stream?: boolean(),
          errors: list(any())
        }

  @enforce_keys [:query]
  defstruct query: nil,
            query_embedding: nil,
            retrieval_results: %{},
            context: nil,
            context_sources: [],
            prompt: nil,
            response: nil,
            evaluations: %{},
            halted?: false,
            stream?: false,
            errors: []

  @doc """
  Creates a new generation struct from a query.
  """
  @spec new(String.t()) :: t()
  def new(query) when is_binary(query), do: %Generation{query: query}

  @doc """
  Puts `query_embedding` in `generation.query_embedding`.
  """
  @spec put_query_embedding(t(), query_embedding :: list(number())) :: t()
  def put_query_embedding(%Generation{} = generation, query_embedding),
    do: %{generation | query_embedding: query_embedding}

  @doc """
  Puts `retrieval_result` at `key` in `generation.retrieval_results`.
  """
  @spec put_retrieval_result(t(), key :: atom(), retrieval_result :: map()) :: t()
  def put_retrieval_result(%Generation{} = generation, key, retrieval_result),
    do: put_in(generation, [Access.key!(:retrieval_results), key], retrieval_result)

  @doc """
  Gets the retrieval result at `key` in `generation.retrieval_results`.
  """
  @spec get_retrieval_result(t(), key :: atom()) :: any()
  def get_retrieval_result(%Generation{} = generation, key),
    do: Map.fetch!(generation.retrieval_results, key)

  @doc """
  Puts `context` in `generation.context`.
  """
  @spec put_context(t(), context :: String.t()) :: t()
  def put_context(%Generation{} = generation, context) when is_binary(context),
    do: %{generation | context: context}

  @doc """
  Puts `context_sources` in `generation.context_sources`.
  """
  @spec put_context_sources(t(), context_sources :: list(String.t())) :: t()
  def put_context_sources(%Generation{} = generation, context_sources)
      when is_list(context_sources),
      do: %{generation | context_sources: context_sources}

  @doc """
  Puts `prompt` in `generation.prompt`.
  """
  @spec put_prompt(t(), prompt :: String.t()) :: t()
  def put_prompt(%Generation{} = generation, prompt) when is_binary(prompt),
    do: %{generation | prompt: prompt}

  @doc """
  Puts `response` in `generation.response`.
  """
  @spec put_response(t(), response :: String.t()) :: t()
  def put_response(%Generation{} = generation, response) when is_binary(response),
    do: %{generation | response: response}

  @doc """
  Puts `evaluation` at `key` in `generation.evaluations`.
  """
  @spec put_evaluation(t(), key :: atom(), evaluation :: any()) :: t()
  def put_evaluation(%Generation{} = generation, key, evaluation),
    do: put_in(generation, [Access.key!(:evaluations), key], evaluation)

  @doc """
  Gets the evaluation at `key` in `generation.evaluations`.
  """
  @spec get_evaluation(t(), key :: atom()) :: any()
  def get_evaluation(%Generation{} = generation, key),
    do: Map.fetch!(generation.evaluations, key)

  @doc """
  Sets `halted?` to `true` to skip all remaining operations.
  """
  @spec halt(t()) :: t()
  def halt(%Generation{} = generation), do: %{generation | halted?: true}

  @doc """
  Appends an error to the existing list of errors.
  """
  @spec add_error(t(), any()) :: t()
  def add_error(%Generation{} = generation, error),
    do: update_in(generation.errors, fn errors -> [error | errors] end)

  @doc """
  Passes `generation.prompt` to `response_function` or `provider` to generate a response.
  If successful, puts the result in `generation.response`.
  """
  @spec generate_response(Generation.t(), response_function() | provider(), stream()) :: Generation.t()
  def generate_response(%Generation{halted?: true} = generation, _response_function, _stream),
    do: generation

  def generate_response(%Generation{prompt: nil}, _response_function, _stream),
    do: raise(ArgumentError, message: "prompt must not be nil")

  def generate_response(%Generation{} = generation, %provider_module{} = provider, stream \\ false) do
    generate_response(generation, &provider_module.generate_text(provider, &1, &2), stream)
  end

  def generate_response(%Generation{} = generation, %provider_module{} = provider, true) do
    false
  end

  def generate_response(%Generation{} = generation, response_function, stream) do
    metadata = %{generation: generation}

    :telemetry.span([:rag, :generate_response], metadata, fn ->
      generation =
        case response_function.(generation.prompt, []) do
          {:ok, response} -> Generation.put_response(generation, response)
          {:error, error} -> generation |> Generation.add_error(error) |> Generation.halt()
        end

      {generation, %{metadata | generation: generation}}
    end)
  end

  # def generate_response(%Generation{} = generation, _response_function, true) do
  #   metadata = %{generation: generation} # do we need this??

  #   :telemetry.span([:rag, :generate_response], metadata, fn ->
  #     generation =
  #       case response_function.(generation.prompt, []) do
  #         {:ok, response} -> Generation.put_response(generation, response)
  #         {:error, error} -> generation |> Generation.add_error(error) |> Generation.halt()
  #       end
  #   end)
  # end
end
