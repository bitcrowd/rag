defmodule Rag.Generation.HallucinationDetection.LangChain do
  @moduledoc """
  Functions to detect hallucinations in generated responses using `LangChain`.
  """

  alias LangChain.Chains.LLMChain
  alias LangChain.Message

  @doc """
  Takes the values of `query`, `response` and `context` from `rag_state` and passes it to an LLM specified by `chain` to detect potential hallucinations.
  Then, puts `hallucination?` in `rag_state`.
  """
  @spec detect_hallucination(%{response: String.t()}, LLMChain.t()) :: %{hallucination?: bool()}
  def detect_hallucination(rag_state, chain) do
    %{query: query, response: response, context: context} = rag_state

    prompt =
      """
      Context information is below.
      ---------------------
      #{context}
      ---------------------
      Given the context information and the query: does the response represent a correct answer only based on the context?
      Produce ONLY the following output: 'YES' or 'NO'
      Query: #{query}
      Response: #{response}
      """

    metadata = %{chain: chain, rag_state: rag_state}

    {:ok, _updated_chain, response} =
      :telemetry.span([:rag, :detect_hallucination], metadata, fn ->
        result =
          chain
          |> LLMChain.add_message(Message.new_user!(prompt))
          |> LLMChain.run()

        {result, metadata}
      end)

    hallucination? = response.content != "YES"

    Map.put(rag_state, :hallucination?, hallucination?)
  end
end
