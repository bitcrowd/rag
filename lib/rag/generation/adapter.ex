defmodule Rag.Generation.Adapter do
  @moduledoc """
  Behaviour for response generation.
  """

  @doc """
  Passes `generation.prompt` to the adapter using `adapter_params` to generate a response.
  Then, puts `response` in `generation`.
  """
  @callback generate_response(generation :: Rag.Generation.t(), adapter_params :: any()) ::
              Rag.Generation.t()
end
