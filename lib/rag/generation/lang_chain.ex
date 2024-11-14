defmodule Rag.Generation.LangChain do
  alias LangChain.Chains.LLMChain
  alias LangChain.Message

  @spec generate_response(
          %{query: binary(), query_results: %{document: binary(), source: binary()}},
          LLMChain.t()
        ) :: %{context: binary(), context_sources: list(binary()), response: binary()}
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
