defmodule Rag.Generation.Bumblebee do
  @moduledoc """
  Functions to generate responses using `Nx.Serving.batched_run/2`. 
  """

  @doc """
  Creates a prompt from `query` and the context extracted from `query_results` and passes it to `serving` to generate a response.
  Then, puts `context`, `context_sources`, and `response` in `rag_state`.
  """
  @spec generate_response(
          %{query: binary(), query_results: %{document: binary(), source: binary()}},
          Nx.Serving.t()
        ) :: %{context: binary(), context_sources: list(binary()), response: binary()}
  def generate_response(rag_state, serving \\ Rag.LLMServing) do
    %{query: query, query_results: query_results} = rag_state

    {context, context_sources} =
      query_results |> Enum.map(&{&1.document, &1.source}) |> Enum.unzip()

    context = Enum.join(context, "\n\n")

    prompt =
      """
      <|system|>
      You are a helpful assistant.</s>
      <|user|>
      Context information is below.
      ---------------------
      #{context}
      ---------------------
      Given the context information and no prior knowledge, answer the query.
      Query: #{query}
      Answer: </s>
      <|assistant|>
      """

    %{results: [result]} = Nx.Serving.batched_run(serving, prompt)

    rag_state
    |> Map.put(:context, context)
    |> Map.put(:context_sources, context_sources)
    |> Map.put(:response, result.text)
  end
end
