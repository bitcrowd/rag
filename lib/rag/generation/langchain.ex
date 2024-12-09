defmodule Rag.Generation.LangChain do
  @moduledoc """
  Functions to generate responses using `LangChain`. 
  """
  alias LangChain.Chains.LLMChain
  alias LangChain.Message

  @doc """
  Passes `prompt` from `rag_state` to an LLM specified by `chain` to generate a response.
  Then, puts `response` in `rag_state`.
  """
  @spec generate_response(%{prompt: String.t()}, LLMChain.t()) :: %{response: String.t()}
  def generate_response(rag_state, chain) do
    %{prompt: prompt} = rag_state

    {:ok, _updated_chain, response} =
      chain
      |> LLMChain.add_message(Message.new_user!(prompt))
      |> LLMChain.run()

    Map.put(rag_state, :response, response.content)
  end
end
