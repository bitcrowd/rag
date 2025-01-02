defmodule Rag.Generation.HallucinationDetection.Http do
  @moduledoc """
  Functions to detect hallucinations in generated responses using an HTTP API.
  """

  alias Rag.Generation

  @doc """
  Takes the values of `query`, `response` and `context` from `generation` and passes it to an HTTP API specified by `params` to detect potential hallucinations.
  Then, puts a new `hallucination` evaluation in `generation`.
  """
  @spec detect_hallucination(Generation.t(), params :: keyword()) :: Generation.t()
  def detect_hallucination(%Generation{} = generation, params) do
    {url, params} = Keyword.pop!(params, :url)
    {put_prompt_function, params} = Keyword.pop!(params, :put_prompt_function)
    {access_response_function, params} = Keyword.pop!(params, :access_response_function)

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

    params = put_prompt_function.(params, prompt)

    metadata = %{generation: generation, url: url, params: params}

    :telemetry.span([:rag, :detect_hallucination], metadata, fn ->
      response = Req.post!(url, params)

      response = access_response_function.(response.body)

      hallucination? = response != "YES"

      generation = put_in(generation, [Access.key!(:evaluations), :hallucination], hallucination?)

      {generation, %{metadata | generation: generation}}
    end)
  end
end
