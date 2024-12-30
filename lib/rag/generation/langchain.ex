defmodule Rag.Generation.LangChain do
  @moduledoc """
  Functions to generate responses using `LangChain`. 
  """

  alias Rag.Generation
  alias LangChain.Chains.LLMChain
  alias LangChain.Message

  @doc """
  Passes `prompt` from `generation` to an LLM specified by `chain` to generate a response.
  Then, puts `response` in `generation`.
  """
  @spec generate_response(Generation.t(), LLMChain.t()) :: Generation.t()
  def generate_response(%Generation{} = generation, chain) do
    %{prompt: prompt} = generation

    metadata = %{chain: chain, generation: generation}

    :telemetry.span([:rag, :generate_response], metadata, fn ->
      {:ok, updated_chain} =
        chain
        |> LLMChain.add_message(Message.new_user!(prompt))
        |> LLMChain.run()

      generation =
        put_in(generation, [Access.key!(:response)], updated_chain.last_message.content)

      {generation, %{metadata | generation: generation}}
    end)
  end
end
