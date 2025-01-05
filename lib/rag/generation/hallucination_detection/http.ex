defmodule Rag.Generation.HallucinationDetection.Http do
  @moduledoc """
  Functions to detect hallucinations in generated responses using an HTTP API.
  """

  alias Rag.Generation
  alias Rag.Generation.Http.Params

  @doc """
  Takes the values of `query`, `response` and `context` from `generation` and passes it to an HTTP API specified by `params` to detect potential hallucinations.
  Then, puts a new `hallucination` evaluation in `generation`.
  """
  @spec detect_hallucination(Generation.t(), params :: Params.t()) :: Generation.t()
  def detect_hallucination(%Generation{} = generation, params) do
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

    params = Params.set_input(params, prompt)

    metadata = %{generation: generation, params: params}

    :telemetry.span([:rag, :detect_hallucination], metadata, fn ->
      response = Req.post!(params.url, params.req_params)

      response = get_response(response, params)

      hallucination? = response != "YES"

      generation = Generation.put_evaluation(generation, :hallucination, hallucination?)

      {generation, %{metadata | generation: generation}}
    end)
  end

  defp get_response(response, params), do: get_in(response.body, params.access_response)
end
