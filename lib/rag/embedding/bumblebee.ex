defmodule Rag.Embedding.Bumblebee do
  @type embedding :: list(number())
  @spec generate_embedding(map(), Nx.Serving.t(), atom(), atom()) :: %{
          atom() => embedding(),
          optional(any) => any
        }
  def generate_embedding(rag_state, serving \\ Rag.EmbeddingServing, source_key, target_key) do
    text = Map.fetch!(rag_state, source_key)

    %{embedding: embedding} = Nx.Serving.batched_run(serving, text)

    Map.put(rag_state, target_key, Nx.to_list(embedding))
  end

  @spec generate_embeddings_batch(list(map()), Nx.Serving.t(), atom(), atom()) ::
          list(%{atom() => embedding(), optional(any) => any})
  def generate_embeddings_batch(
        rag_state_list,
        serving \\ Rag.EmbeddingServing,
        source_key,
        target_key
      ) do
    texts = Enum.map(rag_state_list, &Map.fetch!(&1, source_key))

    embeddings = Nx.Serving.batched_run(serving, texts)

    Enum.zip(rag_state_list, embeddings)
    |> Enum.map(fn {rag_state, embedding} ->
      Map.put(rag_state, target_key, Nx.to_list(embedding.embedding))
    end)
  end
end
