defmodule Rag.Embedding.NxTest do
  use ExUnit.Case
  use Mimic

  alias Rag.{Ai, Embedding, Generation}

  setup do
    %{provider: Ai.Nx.new(%{embeddings_serving: TestEmbeddingsServing})}
  end

  describe "generate_embedding/3" do
    test "takes a string at text_key and returns ingestion map with a list of numbers at embedding_key",
         %{provider: provider} do
      expect(Nx.Serving, :batched_run, fn _serving, _text ->
        [%{embedding: Nx.tensor([1, 2, 3])}]
      end)

      ingestion = %{text: "hello"}

      assert Embedding.generate_embedding(ingestion, provider, []) == %{
               text: "hello",
               embedding: [1, 2, 3]
             }
    end

    test "errors if serving is not available", %{provider: provider} do
      ingestion = %{text: "hello"}

      assert {:noproc, _} =
               catch_exit(Embedding.generate_embedding(ingestion, provider, []))
    end
  end

  describe "generate_embedding/2" do
    test "takes the query from the generation, generates an embedding and puts it into query_embedding",
         %{provider: provider} do
      expect(Nx.Serving, :batched_run, fn _serving, ["query"] ->
        [%{embedding: Nx.tensor([1, 2, 3])}]
      end)

      generation = %Generation{query: "query"}

      assert Embedding.generate_embedding(generation, provider) == %Generation{
               query: "query",
               query_embedding: [1, 2, 3]
             }
    end

    test "errors if serving is not available", %{provider: provider} do
      generation = Generation.new("hello")

      assert {:noproc, _} =
               catch_exit(Embedding.generate_embedding(generation, provider))
    end
  end

  describe "generate_embeddings_batch/3" do
    test "takes a string at text_key and returns ingestion map with a list of numbers at embedding_key",
         %{provider: provider} do
      expect(Nx.Serving, :batched_run, fn _serving, ["hello", "hello again"] ->
        [%{embedding: Nx.tensor([1, 2, 3])}, %{embedding: Nx.tensor([4, 5, 6])}]
      end)

      ingestions = [%{text: "hello"}, %{text: "hello again"}]

      assert [
               %{text: "hello", embedding: [1, 2, 3]},
               %{text: "hello again", embedding: [4, 5, 6]}
             ] ==
               Embedding.generate_embeddings_batch(ingestions, provider, [])
    end

    test "errors if serving is not available", %{provider: provider} do
      ingestions = [%{text: "hello"}]

      assert {:noproc, _} =
               catch_exit(Embedding.generate_embeddings_batch(ingestions, provider, []))
    end
  end
end
