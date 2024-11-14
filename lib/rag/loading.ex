defmodule Rag.Loading do
  @spec load_file(%{source: binary()}) :: %{source: binary(), document: binary()}
  def load_file(rag_state) do
    %{source: file} = rag_state
    Map.put(rag_state, :document, File.read!(file))
  end

  @spec chunk_text(%{document: binary()}) :: %{document: binary(), chunk: binary()}
  def chunk_text(rag_state, opts \\ []) do
    %{document: text} = rag_state
    chunks = TextChunker.split(text, opts)

    for chunk <- chunks, do: Map.put(rag_state, :chunk, chunk.text)
  end
end
