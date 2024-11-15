defmodule Rag.Generation.LangChain do
  @moduledoc """
  Functions to generate responses using `LangChain`. 
  """
  alias LangChain.Chains.LLMChain
  alias LangChain.Message

  @doc """
  Takes the values of `query` and `query_results` from `rag_state`.
  Creates a context from `query_results` and injects `query` and the context into a prompt which is then passed to to an LLM specified by `chain` to generate a response.
  Then, puts `context`, `context_sources`, and `response` in `rag_state`.
  """
  @spec generate_response(
          %{query: String.t(), query_results: %{document: String.t(), source: String.t()}},
          LLMChain.t()
        ) :: %{context: String.t(), context_sources: list(String.t()), response: String.t()}
  def generate_response(rag_state, chain) do
    %{query: query, query_results: query_results} = rag_state

    {context, context_sources} =
      query_results |> Enum.map(&{&1.document, &1.source}) |> Enum.unzip()

    context = Enum.join(context, "\n\n")

    prompt =
      """
      Context information is below.
      ---------------------
      #{context}
      ---------------------
      Given the context information and no prior knowledge, answer the query.
      Query: #{query}
      Answer:
      """

    {:ok, _updated_chain, response} =
      chain
      |> LLMChain.add_message(Message.new_user!(prompt))
      |> LLMChain.run()

    rag_state
    |> Map.put(:context, context)
    |> Map.put(:context_sources, context_sources)
    |> Map.put(:response, response.content)
  end
end
