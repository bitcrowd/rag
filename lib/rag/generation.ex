defmodule Rag.Generation do
  @moduledoc """
  Functions to generate a response and helpers to work with a generation struct.
  """
  alias Rag.Generation

  @type embedding :: list(number())
  @type provider :: struct()
  @type response :: String.t() | Enumerable.t()

  @type response_function :: (String.t(), keyword() -> response())
  @type context_builder_function :: (Generation.t(), keyword() -> String.t())
  @type context_sources_builder_function :: (Generation.t(), keyword() -> list(String.t()))
  @type prompt_builder_function :: (Generation.t(), keyword() -> String.t())

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
          response: response() | nil,
          evaluations: %{optional(atom()) => any()},
          halted?: boolean(),
          errors: list(any()),
          ref: any()
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
            errors: [],
            ref: nil

  @doc """
  Creates a new generation struct from a query.
  """
  @spec new(String.t()) :: t()
  @spec new(String.t(), opts :: keyword()) :: t()
  def new(query, opts \\ []) when is_binary(query) do
    ref = Keyword.get(opts, :ref)
    %Generation{query: query, ref: ref}
  end

  @doc """
  Puts `query_embedding` in `generation.query_embedding`.
  """
  @spec put_query_embedding(t(), query_embedding :: list(number())) :: t()
  def put_query_embedding(%Generation{} = generation, query_embedding),
    do: %{generation | query_embedding: query_embedding}

  @doc """
  Puts `retrieval_result` at `key` in `generation.retrieval_results`.
  """
  @spec put_retrieval_result(t(), key :: atom(), retrieval_result :: any()) :: t()
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
  @spec put_response(t(), response :: response()) :: t()
  def put_response(%Generation{} = generation, response),
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
  @spec generate_response(Generation.t(), response_function() | provider(), keyword()) ::
          Generation.t()
  def generate_response(generation, response_function_or_provider, opts \\ [])

  def generate_response(%Generation{halted?: true} = generation, _response_function, _opts),
    do: generation

  def generate_response(%Generation{prompt: nil}, _response_function, _opts),
    do: raise(ArgumentError, message: "prompt must not be nil")

  def generate_response(%Generation{} = generation, %provider_module{} = provider, opts) do
    generate_response(generation, &provider_module.generate_text(provider, &1, &2), opts)
  end

  def generate_response(%Generation{} = generation, response_function, opts) do
    metadata = %{generation: generation}

    :telemetry.span([:rag, :generate_response], metadata, fn ->
      generation =
        case response_function.(generation.prompt, opts) do
          {:ok, response} ->
            Generation.put_response(generation, response)

          {:error, error} ->
            generation |> Generation.add_error(error) |> Generation.halt()
        end

      {generation, %{metadata | generation: generation}}
    end)
  end

  @doc """
  Passes `generation` and `opts` to `context_builder_function` to determine the context.
  Then, puts the context in `generation.context`.
  """
  @spec build_context(t(), context_builder_function(), keyword()) :: t()
  def build_context(%Generation{} = generation, context_builder_function, opts \\ [])
      when is_function(context_builder_function, 2) do
    context = context_builder_function.(generation, opts)

    Generation.put_context(generation, context)
  end

  @doc """
  Passes `generation` and `opts` to `context_sources_builder_function` to determine the context sources.
  Then, puts the context sources in `generation.context_sources`.
  """
  @spec build_context_sources(t(), context_sources_builder_function(), keyword()) :: t()
  def build_context_sources(
        %Generation{} = generation,
        context_sources_builder_function,
        opts \\ []
      )
      when is_function(context_sources_builder_function, 2) do
    context_sources = context_sources_builder_function.(generation, opts)

    Generation.put_context_sources(generation, context_sources)
  end

  @doc """
  Passes `generation` and `opts` to `prompt_builder_function` to determine the prompt.
  Then, puts the prompt in `generation.prompt`.
  """
  @spec build_prompt(t(), prompt_builder_function(), keyword()) :: t()
  def build_prompt(%Generation{} = generation, prompt_builder_function, opts \\ [])
      when is_function(prompt_builder_function, 2) do
    prompt = prompt_builder_function.(generation, opts)

    Generation.put_prompt(generation, prompt)
  end
end
