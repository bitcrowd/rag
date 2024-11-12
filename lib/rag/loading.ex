defmodule Rag.Loading do
  def load_file(%{source: file} = input) do
    Map.put(input, :document, File.read!(file))
  end

  def chunk_text(%{document: text} = input, opts \\ []) do
    chunks = TextChunker.split(text, opts)

    for chunk <- chunks, do: Map.put(input, :chunk, chunk.text)
  end
end
