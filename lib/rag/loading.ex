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

  @doc """
  Chunks the content at `document` in `ingestion` using `TextChunker.split/2`.
  Returns a list with the chunk stored in `chunk` in `ingestion` for each of the chunks.
  """
  @spec chunk_text(map(), keyword()) :: map()
  def chunk_text(ingestion, text_key, opts \\ []) do
    text = Map.fetch!(ingestion, text_key)
    chunks = TextChunker.split(text, opts)

    Enum.map(chunks, &Map.put(ingestion, :chunk, &1.text))
  end
end
