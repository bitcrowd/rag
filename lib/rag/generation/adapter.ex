defmodule Rag.Generation.Adapter do
  @moduledoc """
  Behaviour for response generation.
  """

  alias Rag.Generation

  @doc """
  Passes `generation.prompt` to the adapter using `adapter_params` to generate a response.
  Then, puts `response` in `generation`.
  """
  @callback generate_response(Generation.t(), adapter_params :: any()) :: Generation.t()
end
