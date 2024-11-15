defmodule Rag.Loading do
  @moduledoc """
  Functions to load and transform data from various sources and formats.
  """

  @doc """
  Reads the file from the filepath at `source` in `rag_state` and puts it in `rag_state` at `document`.
  """
  @spec load_file(%{source: binary()}) :: %{source: binary(), document: binary()}
  def load_file(rag_state) do
    %{source: file} = rag_state
    Map.put(rag_state, :document, File.read!(file))
  end

  @doc """
  Chunks the content at `document` in `rag_state` using `TextChunker.split/2`.
  Returns a list with the chunk stored in `chunk` in `rag_state` for each of the chunks.
  """
  @spec chunk_text(%{document: binary()}) :: %{document: binary(), chunk: binary()}
  def chunk_text(rag_state, opts \\ []) do
    %{document: text} = rag_state
    chunks = TextChunker.split(text, opts)

    for chunk <- chunks, do: Map.put(rag_state, :chunk, chunk.text)
  end
end
