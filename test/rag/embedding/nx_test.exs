defmodule Rag.Embedding.NxTest do
  use ExUnit.Case
  use Mimic

  alias Rag.Embedding

  describe "generate_embedding/4" do
    test "takes a string at source_key and returns rag_state map with a list of numbers at target_key" do
      expect(Nx.Serving, :batched_run, fn _serving, _text ->
        %{embedding: Nx.tensor([1, 2, 3])}
      end)

      rag_state = %{text: "hello"}

      assert Embedding.Nx.generate_embedding(rag_state, :text, :output) == %{
               text: "hello",
               output: [1, 2, 3]
             }
    end

    test "errors if source_key is not in rag_state" do
      rag_state = %{text: "hello"}

      assert_raise KeyError, fn ->
        Embedding.Nx.generate_embedding(rag_state, :non_existing_key, :output)
      end
    end

    test "errors if serving is not available" do
      rag_state = %{text: "hello"}

      assert {:noproc, _} =
               catch_exit(
                 Embedding.Nx.generate_embedding(
                   rag_state,
                   NonExisting.Serving,
                   :text,
                   :output
                 )
               )
    end
  end

  describe "generate_embeddings_batch/4" do
    test "takes a string at source_key and returns rag_state map with a list of numbers at target_key" do
      expect(Nx.Serving, :batched_run, fn _serving, ["hello", "hello again"] ->
        [%{embedding: Nx.tensor([1, 2, 3])}, %{embedding: Nx.tensor([4, 5, 6])}]
      end)

      rag_state_list = [%{text: "hello"}, %{text: "hello again"}]

      assert [%{text: "hello", output: [1, 2, 3]}, %{text: "hello again", output: [4, 5, 6]}] ==
               Embedding.Nx.generate_embeddings_batch(rag_state_list, :text, :output)
    end

    test "errors if source_key is not in rag_state" do
      rag_state_list = [%{text: "hello"}]

      assert_raise KeyError, fn ->
        Embedding.Nx.generate_embeddings_batch(rag_state_list, :non_existing_key, :output)
      end
    end

    test "errors if serving is not available" do
      rag_state_list = [%{text: "hello"}]

      assert {:noproc, _} =
               catch_exit(
                 Embedding.Nx.generate_embeddings_batch(
                   rag_state_list,
                   NonExisting.Serving,
                   :text,
                   :output
                 )
               )
    end
  end
end
