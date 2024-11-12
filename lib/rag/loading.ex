defmodule Rag.Loading do
  @spec load_file(%{source: binary()}) :: %{source: binary(), document: binary()}
  def load_file(%{source: file} = input) do
    Map.put(input, :document, File.read!(file))
  end

  @spec chunk_text(%{document: binary()}) :: %{document: binary(), chunk: binary()}
  def chunk_text(%{document: text} = input, opts \\ []) do
    chunks = TextChunker.split(text, opts)

    for chunk <- chunks, do: Map.put(input, :chunk, chunk.text)
  end
end
