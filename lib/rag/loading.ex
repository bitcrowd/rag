defmodule Rag.Loading do
  @moduledoc """
  Functions to load and transform data from various sources and formats.
  """

  @doc """
  Reads the file from the filepath at `source` in `ingestion` and puts it in `ingestion` at `document`.
  """
  @spec load_file(map()) :: map()
  def load_file(ingestion) do
    %{source: file} = ingestion
    Map.put(ingestion, :document, File.read!(file))
  end
end
