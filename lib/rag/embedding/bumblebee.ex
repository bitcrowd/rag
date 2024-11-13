defmodule Rag.Embedding.Bumblebee do
  @type embedding :: list(number())
  @spec generate_embedding(map(), Nx.Serving.t(), atom(), atom()) :: %{
          atom() => embedding(),
          optional(any) => any
        }
  def generate_embedding(input, serving \\ Rag.EmbeddingServing, source_key, target_key) do
    text = input[source_key]

    %{embedding: embedding} = Nx.Serving.batched_run(serving, text)

    Map.put(input, target_key, Nx.to_list(embedding))
  end

  @spec generate_embedding(list(map()), Nx.Serving.t(), atom(), atom()) ::
          list(%{atom() => embedding(), optional(any) => any})
  def generate_embeddings_batch(inputs, serving \\ Rag.EmbeddingServing, source_key, target_key) do
    texts = Enum.map(inputs, &Map.fetch!(&1, source_key))

    embeddings = Nx.Serving.batched_run(serving, texts)

    Enum.zip(inputs, embeddings)
    |> Enum.map(fn {input, embedding} ->
      Map.put(input, target_key, Nx.to_list(embedding.embedding))
    end)
  end
end
