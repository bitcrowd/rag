defmodule Rag.Embedding.Nx do
  @moduledoc """
  Functions to generate embeddings using `Nx.Serving.batched_run/2`. 
  """

  @doc """
  Passes the value of `rag_state` at `source_key` to `serving` to generate an embedding.
  Then, puts the embedding in `rag_state` at `target_key`.
  """
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

  @doc """
  Passes the values of each element of `rag_state_list` at `source_key` as a batch to `serving` to generate all embeddings at once.
  Then, puts the embedding in each element of `rag_state_list` at `target_key`.
  """
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
