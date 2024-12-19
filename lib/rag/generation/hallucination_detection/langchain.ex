defmodule Rag.Generation.HallucinationDetection.LangChain do
  @moduledoc """
  Functions to detect hallucinations in generated responses using `LangChain`.
  """

  alias Rag.Generation
  alias LangChain.Chains.LLMChain
  alias LangChain.Message

  @doc """
  Takes the values of `query`, `response` and `context` from `generation` and passes it to an LLM specified by `chain` to detect potential hallucinations.
  Then, puts a new `hallucination` evaluation in `generation`.
  """
  @spec detect_hallucination(Generation.t(), LLMChain.t()) :: Generation.t()
  def detect_hallucination(%Generation{} = generation, chain) do
    %{query: query, response: response, context: context} = generation

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

    metadata = %{chain: chain, generation: generation}

    :telemetry.span([:rag, :detect_hallucination], metadata, fn ->
      {:ok, _updated_chain, response} =
        chain
        |> LLMChain.add_message(Message.new_user!(prompt))
        |> LLMChain.run()

      hallucination? = response.content != "YES"

      generation = put_in(generation, [Access.key!(:evaluations), :hallucination], hallucination?)

      {generation, %{metadata | generation: generation}}
    end)
  end
end
